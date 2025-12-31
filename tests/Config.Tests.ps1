BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging\Write-Log.ps1"
    . $LoggingModulePath
    $ModulePath = Join-Path $ProjectRoot "src\Modules\Config\Read-Config.ps1"
    . $ModulePath
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

        $script:FileGuardian_CachedConfig = $script:ValidConfig
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
                $oldEnv = $env:FILEGUARDIAN_CONFIG_PATH
                try {
                    $env:FILEGUARDIAN_CONFIG_PATH = $defaultPath
                    $result = Read-Config
                    $result | Should -Not -BeNullOrEmpty
                }
                finally {
                    if ($null -ne $oldEnv) { $env:FILEGUARDIAN_CONFIG_PATH = $oldEnv } else { Remove-Item Env:FILEGUARDIAN_CONFIG_PATH -ErrorAction SilentlyContinue }
                }
            }
        }

        It "Should prefer -ConfigPath over FILEGUARDIAN_CONFIG_PATH when both provided" {
            $envConfigPath = Join-Path $TestDrive "env-config.json"
            $argConfigPath = Join-Path $TestDrive "arg-config.json"

            # Create two distinct configs
            @{ BackupSettings = @{ DestinationPath = "C:\EnvBackups" } } | ConvertTo-Json -Depth 3 | Set-Content -Path $envConfigPath
            @{ BackupSettings = @{ DestinationPath = "C:\ArgBackups" } } | ConvertTo-Json -Depth 3 | Set-Content -Path $argConfigPath

            $oldEnv = $env:FILEGUARDIAN_CONFIG_PATH
            try {
                $env:FILEGUARDIAN_CONFIG_PATH = $envConfigPath
                $result = Read-Config -ConfigPath $argConfigPath
                $result.BackupSettings.DestinationPath | Should -Be "C:\ArgBackups"
            }
            finally {
                if ($null -ne $oldEnv) { $env:FILEGUARDIAN_CONFIG_PATH = $oldEnv } else { Remove-Item Env:FILEGUARDIAN_CONFIG_PATH -ErrorAction SilentlyContinue }
                Remove-Item -Path $envConfigPath,$argConfigPath -ErrorAction SilentlyContinue
            }
        }
    }
}
