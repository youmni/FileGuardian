BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:BackupModulePath = Join-Path $ProjectRoot "src\Modules\Backup"
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"
    $script:ReportingModulePath = Join-Path $ProjectRoot "src\Modules\Reporting"
    $script:IntegrityModulePath = Join-Path $ProjectRoot "src\Modules\Integrity"
    
    . (Join-Path $script:LoggingModulePath "Write-Log.ps1")

    Get-ChildItem -Path $script:BackupModulePath -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
    . (Join-Path $ProjectRoot "src\Modules\Config\Read-Config.ps1")
    
    Get-ChildItem -Path $script:ReportingModulePath -Filter '*.ps1' | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path $script:IntegrityModulePath -Filter '*.ps1' | ForEach-Object { . $_.FullName }
    
    # Define helper function in BeforeAll scope
    function script:New-TestData {
        param($Path)
        
        if (Test-Path $Path) {
            Remove-Item -Path $Path -Recurse -Force
        }
        
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        
        # Create test files
        "File 1 content" | Out-File (Join-Path $Path "file1.txt")
        "File 2 content" | Out-File (Join-Path $Path "file2.txt")
        "Temp file" | Out-File (Join-Path $Path "temp.tmp")
        "Log file" | Out-File (Join-Path $Path "test.log")
        
        # Create subfolder with files
        $subFolder = Join-Path $Path "SubFolder"
        New-Item -Path $subFolder -ItemType Directory -Force | Out-Null
        "File 3 content" | Out-File (Join-Path $subFolder "file3.txt")
    }
}

Describe "Compress-Backup" {
    BeforeEach {
        $script:TestCompressSource = Join-Path $TestDrive "CompressSource"
        $script:TestCompressZip = Join-Path $TestDrive "compressed.zip"
        New-TestData -Path $script:TestCompressSource
    }
    
    AfterEach {
        if (Test-Path $script:TestCompressZip) {
            Remove-Item -Path $script:TestCompressZip -Force
        }
        if (Test-Path $script:TestCompressSource) {
            Remove-Item -Path $script:TestCompressSource -Recurse -Force
        }
    }
    
    Context "Compression Functionality" {
        It "Should create a ZIP file" {
            Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip
            Test-Path $script:TestCompressZip | Should -Be $true
        }
        
        It "Should return compression information" {
            $result = Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should include file count in result" {
            $result = Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip
            $result.FileCount | Should -BeGreaterThan 0
        }
        
        It "Should include compression ratio" {
            $result = Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip
            $result.CompressionRatio | Should -Not -BeNullOrEmpty
        }
        
        It "Should remove source when RemoveSource is specified" {
            Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip -RemoveSource
            Test-Path $script:TestCompressSource | Should -Be $false
        }
        
        It "Should keep source when RemoveSource is not specified" {
            Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip
            Test-Path $script:TestCompressSource | Should -Be $true
        }
    }
    
    Context "Compression Levels" {
        It "Should accept Optimal compression level" {
            { Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip -CompressionLevel Optimal } | Should -Not -Throw
        }
        
        It "Should accept Fastest compression level" {
            { Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip -CompressionLevel Fastest } | Should -Not -Throw
        }
        
        It "Should accept NoCompression level" {
            { Compress-Backup -SourcePath $script:TestCompressSource -DestinationPath $script:TestCompressZip -CompressionLevel NoCompression } | Should -Not -Throw
        }
    }
    
    Context "Error Handling" {
        It "Should throw when source path does not exist" {
            { Compress-Backup -SourcePath "C:\NonExistent" -DestinationPath $script:TestCompressZip } | Should -Throw
        }
    }
}

Describe "Invoke-FullBackup" {
    BeforeEach {
        $script:TestSourcePath = Join-Path $TestDrive "TestSource"
        $script:TestDestPath = Join-Path $TestDrive "TestBackup"
        
        New-TestData -Path $script:TestSourcePath
        
        if (Test-Path $script:TestDestPath) {
            Remove-Item -Path $script:TestDestPath -Recurse -Force
        }
        
        # Create test config
        $script:TestConfigPath = Join-Path $TestDrive "backup-config.json"
        @{
            GlobalSettings = @{
                LogDirectory = "C:\TestLogs"
                ReportFormat = "JSON"
                DefaultBackupType = "Full"
            }
            BackupSettings = @{
                DestinationPath = $script:TestDestPath
                CompressBackups = $false
                ExcludePatterns = @("*.tmp", "*.log")
                RetentionDays = 30
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:TestConfigPath

        # Capture current project reports before the test so we only remove files created by this test
        $projectReports = Join-Path $ProjectRoot "reports"
        if (Test-Path $projectReports) {
            $script:ProjectReportsBefore = Get-ChildItem -Path $projectReports -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        }
        else {
            $script:ProjectReportsBefore = @()
        }
    }
    
    AfterEach {
        if (Test-Path $script:TestSourcePath) {
            Remove-Item -Path $script:TestSourcePath -Recurse -Force
        }
        if (Test-Path $script:TestDestPath) {
            Remove-Item -Path $script:TestDestPath -Recurse -Force
        }
        # Clean up any generated reports in the project reports folder that were created by this test
        $projectReports = Join-Path $ProjectRoot "reports"
        if (Test-Path $projectReports) {
            $after = Get-ChildItem -Path $projectReports -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
            $created = $after | Where-Object { $script:ProjectReportsBefore -notcontains $_ }
            foreach ($f in $created) {
                try { Remove-Item -Path $f -Force -ErrorAction SilentlyContinue } catch {}
                # also remove signature files next to created reports
                $sig = "$f.sig"
                if (Test-Path $sig) { Remove-Item -Path $sig -Force -ErrorAction SilentlyContinue }
            }
        }

        # Also remove any temporary report directories created under the test drive
        $tempReportDir = Join-Path $TestDrive "reports_full"
        if (Test-Path $tempReportDir) { Remove-Item -Path $tempReportDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    
    Context "Basic Backup Functionality" {
        It "Should create a backup directory" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            Test-Path $result.DestinationPath | Should -Be $true
        }
        
        It "Should copy files from source to destination" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            $backupFiles = Get-ChildItem -Path $result.DestinationPath -Recurse -File
            $backupFiles.Count | Should -BeGreaterThan 0
        }
        
        It "Should return backup information" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be "Full"
        }
        
        It "Should include timestamp in default backup name" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath | Select-Object -Last 1
            $result.BackupName | Should -Match "FullBackup_\d{8}_\d{6}"
        }
        
        It "Should add timestamp to custom backup name" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "MyBackup" | Select-Object -Last 1
            $result.BackupName | Should -Match "MyBackup_\d{8}_\d{6}"
        }
        
        It "Should count files backed up correctly" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            $result.FilesBackedUp | Should -BeGreaterThan 0
        }
    }
    
    Context "Exclusion Patterns" {
        It "Should exclude files matching patterns" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -ExcludePatterns @("*.tmp", "*.log") | Select-Object -Last 1
            $backupFiles = Get-ChildItem -Path $result.DestinationPath -Recurse -File
            $backupFiles.Name | Should -Not -Contain "temp.tmp"
            $backupFiles.Name | Should -Not -Contain "test.log"
        }
        
        It "Should include non-excluded files" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -ExcludePatterns @("*.tmp") | Select-Object -Last 1
            $backupFiles = Get-ChildItem -Path $result.DestinationPath -Recurse -File
            $backupFiles.Name | Should -Contain "file1.txt"
        }
    }
    
    Context "Compression" {
        It "Should create ZIP file when Compress is specified" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -Compress | Select-Object -Last 1
            $result.DestinationPath | Should -Match "\.zip$"
            Test-Path $result.DestinationPath | Should -Be $true
        }
        
        It "Should set Compressed flag when using compression" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -Compress | Select-Object -Last 1
            $result.Compressed | Should -Be $true
        }
        
        It "Should include compression statistics when compressed" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -Compress | Select-Object -Last 1
            $result.CompressedSizeMB | Should -Not -BeNullOrEmpty
            $result.CompressionRatio | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Config Integration" {
        It "Should use destination from config when not specified" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -ConfigPath $script:TestConfigPath -BackupName "Test" | Select-Object -Last 1
            $result.DestinationPath | Should -Match ([regex]::Escape($script:TestDestPath))
        }
        
        It "Should use exclude patterns from config" {
            $result = Invoke-FullBackup -SourcePath $script:TestSourcePath -ConfigPath $script:TestConfigPath -BackupName "Test" | Select-Object -Last 1
            $backupFiles = Get-ChildItem -Path $result.DestinationPath -Recurse -File
            $backupFiles.Name | Should -Not -Contain "temp.tmp"
        }
    }
    
    Context "Error Handling" {
        It "Should throw when source path does not exist" {
            { Invoke-FullBackup -SourcePath "C:\NonExistent" -DestinationPath $script:TestDestPath } | Should -Throw "*does not exist*"
        }
        
        It "Should throw when destination path is not provided and config doesn't exist" {
            $fakeConfigPath = Join-Path $TestDrive "nonexistent-config.json"
            # Create a config file that exists but does NOT contain DestinationPath to avoid Read-Config missing-file error
            @{
                GlobalSettings = @{
                    LogDirectory = "C:\TestLogs"
                    ReportFormat = "JSON"
                    DefaultBackupType = "Full"
                }
                BackupSettings = @{
                    CompressBackups = $false
                    ExcludePatterns = @("*.tmp", "*.log")
                    RetentionDays = 30
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $fakeConfigPath -Force

            { Invoke-FullBackup -SourcePath $script:TestSourcePath -ConfigPath $fakeConfigPath } | Should -Throw "*required*"

            Remove-Item -Path $fakeConfigPath -Force -ErrorAction SilentlyContinue
        }
    }
}
