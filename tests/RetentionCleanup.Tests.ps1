BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"
    Import-Module (Join-Path $script:LoggingModulePath "Write-Log.psm1") -Force

    # Import function under test
    $script:CleanupModulePath = Join-Path $ProjectRoot "src\Modules\Backup"
    Import-Module (Join-Path $script:CleanupModulePath "Invoke-RetentionCleanup.psm1") -Force

    # Prepare test paths
    $script:configPath = Join-Path $TestDrive "backup-config.json"
    $script:backupDir = Join-Path $TestDrive "RetentionBackups\TestBackup"
    New-Item -Path $script:backupDir -ItemType Directory -Force | Out-Null
}

Describe "Invoke-RetentionCleanup" {
    BeforeEach {
        # Create a minimal config with one enabled and one disabled backup
        $config = @{
            BackupSettings = @{ DestinationPath = $script:backupDir; RetentionDays = 7 }
            ScheduledBackups = @(
                @{ Name = 'TestBackup'; Enabled = $true; BackupPath = $script:backupDir; RetentionDays = 7 },
                @{ Name = 'DisabledBackup'; Enabled = $false; BackupPath = (Join-Path $TestDrive 'Disabled') }
            )
        }

        $config | ConvertTo-Json -Depth 5 | Set-Content $script:configPath
    }

    Context "When backups are configured" {
        It "removes old backups for enabled entry" {
            # Create an old backup folder inside the backup directory
            $oldBackup = Join-Path $script:backupDir "TestBackup_OLD"
            New-Item -Path $oldBackup -ItemType Directory -Force | Out-Null
            # Make it older than retention (set CreationTime)
            (Get-Item $oldBackup).CreationTime = (Get-Date).AddDays(-30)

            Invoke-RetentionCleanup -ConfigPath $script:configPath

            Test-Path $oldBackup | Should -Be $false
        }

        It "does not remove backups for disabled entry" {
            $disabledDir = Join-Path (Join-Path $TestDrive 'Disabled') "DisabledBackup_OLD"
            New-Item -Path $disabledDir -ItemType Directory -Force | Out-Null
            (Get-Item $disabledDir).CreationTime = (Get-Date).AddDays(-30)

            Invoke-RetentionCleanup -ConfigPath $script:configPath

            Test-Path $disabledDir | Should -Be $true
        }
    }

    Context "Error handling and config" {
        It "returns null when config file missing" {
            $missing = Join-Path $TestDrive "nope.json"
            { Invoke-RetentionCleanup -ConfigPath $missing -ErrorAction SilentlyContinue } | Should -Not -Throw

            $res = Invoke-RetentionCleanup -ConfigPath $missing -ErrorAction SilentlyContinue
            $res | Where-Object { $_ -ne $null } | Should -BeNullOrEmpty
        }
    }
}