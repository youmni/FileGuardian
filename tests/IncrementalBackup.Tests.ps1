BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:BackupModulePath = Join-Path $ProjectRoot "src\Modules\Backup"
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"
    
    # Import Logging module first (dependency)
    . (Join-Path $script:LoggingModulePath "Write-Log.ps1")

    # Dot-source all Backup module .ps1 files (helpers and public)
    Get-ChildItem -Path $script:BackupModulePath -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
    . (Join-Path $ProjectRoot "src\Modules\Config\Read-Config.ps1")
    $script:IntegrityModulePath = Join-Path $ProjectRoot "src\Modules\Integrity"
    Get-ChildItem -Path $script:IntegrityModulePath -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
    
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

Describe "Invoke-IncrementalBackup" {
    BeforeEach {
        $script:TestSourcePath = Join-Path $TestDrive "TestSource"
        $script:TestDestPath = Join-Path $TestDrive "TestBackup"
        
        New-TestData -Path $script:TestSourcePath
        # Ensure integrity helper is loaded for each test run
        . (Join-Path $ProjectRoot "src\Modules\Integrity\Get-FileIntegrityHash.ps1")
        
        if (Test-Path $script:TestDestPath) {
            Remove-Item -Path $script:TestDestPath -Recurse -Force
        }
        
        # Create test config with default backup type Incremental
        $script:TestConfigPath = Join-Path $TestDrive "backup-config-incremental.json"
        @{
            GlobalSettings = @{
                LogDirectory = "C:\TestLogs"
                ReportFormat = "JSON"
                DefaultBackupType = "Incremental"
            }
            BackupSettings = @{
                DestinationPath = $script:TestDestPath
                CompressBackups = $false
                ExcludePatterns = @("*.tmp", "*.log")
                RetentionDays = 30
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:TestConfigPath
        
        # Ensure destination and states folder exist and create a fake previous state (latest.json)
        if (-not (Test-Path $script:TestDestPath)) {
            New-Item -Path $script:TestDestPath -ItemType Directory -Force | Out-Null
        }
        $stateDir = Join-Path $script:TestDestPath "states"
        if (-not (Test-Path $stateDir)) {
            New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
        }

        # Build a minimal previous state matching expected structure
        $resolvedSource = (Resolve-Path $script:TestSourcePath).Path
        $previousState = [PSCustomObject]@{
            SourcePath = $resolvedSource
            Timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
            FileCount = 5
            Files = @(
                @{ RelativePath = 'file1.txt'; Hash = 'hash1' },
                @{ RelativePath = 'file2.txt'; Hash = 'hash2' },
                @{ RelativePath = 'temp.tmp'; Hash = 'hash3' },
                @{ RelativePath = 'test.log'; Hash = 'hash4' },
                @{ RelativePath = 'SubFolder\file3.txt'; Hash = 'hash5' }
            )
        }
        $latestFile = Join-Path $stateDir "latest.json"
        $previousState | ConvertTo-Json -Depth 6 | Set-Content -Path $latestFile -Force
    }

    AfterEach {
        if (Test-Path $script:TestSourcePath) {
            Remove-Item -Path $script:TestSourcePath -Recurse -Force
        }
        if (Test-Path $script:TestDestPath) {
            Remove-Item -Path $script:TestDestPath -Recurse -Force
        }
        if (Test-Path $script:TestConfigPath) {
            Remove-Item -Path $script:TestConfigPath -Force -ErrorAction SilentlyContinue
        }
        # Clean up any temporary report directories created under the test drive
        $tempReportDir = Join-Path $TestDrive "reports_incremental"
        if (Test-Path $tempReportDir) { Remove-Item -Path $tempReportDir -Recurse -Force -ErrorAction SilentlyContinue }
        # Also remove any report files created under the test drive (json/html/csv)
        try {
            Get-ChildItem -Path $TestDrive -Recurse -File -Include *.json,*.html,*.csv -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like "*report*" -or $_.DirectoryName -like "*reports*" } |
                ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }
        }
        catch {
            Write-Verbose "No report files to clean up."
        }
    }

    Context "Basic Incremental Functionality" {
        It "Should create a backup directory" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            Test-Path $result.DestinationPath | Should -Be $true
        }

        It "Should copy files from source to destination" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            $backupFiles = Get-ChildItem -Path $result.DestinationPath -Recurse -File
            $backupFiles.Count | Should -BeGreaterThan 0
        }

        It "Should return backup information with type Incremental" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be "Incremental"
        }

        It "Should include timestamp in default backup name" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath | Select-Object -Last 1
            $result.BackupName | Should -Match "IncrementalBackup_\d{8}_\d{6}"
        }

        It "Should add timestamp to custom backup name" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "MyBackup" | Select-Object -Last 1
            $result.BackupName | Should -Match "MyBackup_\d{8}_\d{6}"
        }

        It "Should count files backed up correctly" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" | Select-Object -Last 1
            $result.FilesBackedUp | Should -BeGreaterThan 0
        }
    }

    Context "Exclusions and Compression" {
        It "Should exclude files matching patterns" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -ExcludePatterns @("*.tmp", "*.log") | Select-Object -Last 1
            $backupFiles = Get-ChildItem -Path $result.DestinationPath -Recurse -File
            $backupFiles.Name | Should -Not -Contain "temp.tmp"
            $backupFiles.Name | Should -Not -Contain "test.log"
        }

        It "Should create ZIP file when Compress is specified" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -Compress | Select-Object -Last 1
            $result.DestinationPath | Should -Match "\.zip$"
            Test-Path $result.DestinationPath | Should -Be $true
        }

        It "Should set Compressed flag when using compression" {
            $result = Invoke-IncrementalBackup -SourcePath $script:TestSourcePath -DestinationPath $script:TestDestPath -BackupName "Test" -Compress | Select-Object -Last 1
            $result.Compressed | Should -Be $true
        }
    }

    Context "Error Handling" {
        It "Should throw when source path does not exist" {
            { Invoke-IncrementalBackup -SourcePath "C:\NonExistent" -DestinationPath $script:TestDestPath } | Should -Throw "*does not exist*"
        }
    }
}
