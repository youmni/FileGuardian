BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging\Logging.psd1"
    Import-Module $LoggingModulePath -Force
    $ModulePath = Join-Path $ProjectRoot "src\Modules\Config\Read-Config.psm1"
    Import-Module $ModulePath -Force
}

Describe "Read-Config" {
    BeforeEach {
        # Create test config file
        $script:TestConfigPath = Join-Path $TestDrive "test-config.json"
        $script:ValidConfig = @{
            GlobalSettings = @{
                LogDirectory = "C:\TestLogs"
                ReportFormat = "JSON"
                DefaultBackupType = "Full"
            }
            BackupSettings = @{
                DestinationPath = "C:\TestBackups"
                CompressBackups = $true
                ExcludePatterns = @("*.tmp", "*.log")
                RetentionDays = 30
            }
        }
        $script:ValidConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $script:TestConfigPath
    }
    Context "Valid Configuration File" {

        It "Should read a valid config file successfully" {
            $result = Read-Config -ConfigPath $script:TestConfigPath
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should contain GlobalSettings section" {
            $result = Read-Config -ConfigPath $script:TestConfigPath
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
        }
        
        It "Should contain BackupSettings section" {
            $result = Read-Config -ConfigPath $script:TestConfigPath
            $result.BackupSettings | Should -Not -BeNullOrEmpty
        }
        
        It "Should read LogDirectory correctly" {
            $result = Read-Config -ConfigPath $script:TestConfigPath
            $result.GlobalSettings.LogDirectory | Should -Be "C:\TestLogs"
        }
        
        It "Should read DestinationPath correctly" {
            $result = Read-Config -ConfigPath $script:TestConfigPath
            $result.BackupSettings.DestinationPath | Should -Be "C:\TestBackups"
        }
        
        It "Should read CompressBackups setting correctly" {
            $result = Read-Config -ConfigPath $script:TestConfigPath
            $result.BackupSettings.CompressBackups | Should -Be $true
        }
        
        It "Should read ExcludePatterns as array" {
            $result = Read-Config -ConfigPath $script:TestConfigPath
            $result.BackupSettings.ExcludePatterns | Should -HaveCount 2
            $result.BackupSettings.ExcludePatterns | Should -Contain "*.tmp"
        }
    }
    
    Context "Invalid Configuration File" {
        It "Should throw error when config file does not exist" {
            { Read-Config -ConfigPath "C:\NonExistent\config.json" } | Should -Throw "*not found*"
        }
        
        It "Should throw error when config file is not valid JSON" {
            $invalidPath = Join-Path $TestDrive "invalid.json"
            "This is not JSON" | Set-Content -Path $invalidPath
            { Read-Config -ConfigPath $invalidPath } | Should -Throw
        }
        
        It "Should throw error when config file is empty" {
            $emptyPath = Join-Path $TestDrive "empty.json"
            "" | Set-Content -Path $emptyPath
            { Read-Config -ConfigPath $emptyPath } | Should -Throw
        }
    }
    
    Context "Default Config Path" {
        It "Should use default path when no path specified" {
            # This will fail if default config doesn't exist, which is expected behavior
            $defaultPath = Join-Path $ProjectRoot "config\backup-config.json"
            if (Test-Path $defaultPath) {
                $result = Read-Config
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}
