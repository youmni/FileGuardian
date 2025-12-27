<#
.SYNOPSIS
    Cleans up old backups according to retention settings from configuration.

.DESCRIPTION
    Reads the backup configuration and removes old backups based on the configured
    retention period. This function is intended to be called from the unified
    `Invoke-FileGuardian -Action Cleanup` command but can also be invoked directly
    when imported as a module.

.PARAMETER BackupName
    Optional name of a backup configuration to target. When omitted all configured
    scheduled backups are processed.

.PARAMETER ConfigPath
    Optional path to the JSON configuration file. When omitted the module's
    repository-relative default `config\backup-config.json` is used.

.OUTPUTS
    Returns the combined result objects produced by `Invoke-BackupRetention` for
    each processed backup. The object typically contains `DeletedCount` and
    `FreedSpaceMB` properties.

.EXAMPLE
    Invoke-RetentionCleanup -BackupName 'DailyColruytBackup'

.EXAMPLE
    Invoke-RetentionCleanup

.NOTES
    This function requires the `Invoke-BackupRetention` helper from the Backup
    module to be available (it is a nested module in the `FileGuardian` manifest).
#>
function Invoke-RetentionCleanup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BackupName,

        [Parameter()]
        [string]$ConfigPath
    )

    begin {
        # Determine sensible default for config path when used as a nested module
        if (-not $ConfigPath) {
            $moduleRoot = (Split-Path $PSScriptRoot -Parent -Parent)
            $ConfigPath = Join-Path $moduleRoot "config\backup-config.json"
        }

        if (-not (Test-Path $ConfigPath)) {
            Write-Error "Configuration file not found: $ConfigPath"
            return $null
        }

        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Error "Failed to read configuration: $_"
            return $null
        }

        # Determine which backups to clean up
        $backupsToClean = if ($BackupName) {
            $found = $config.ScheduledBackups | Where-Object { $_.Name -eq $BackupName }
            if (-not $found) {
                Write-Warning "Backup '$BackupName' not found in configuration."
                return $null
            }
            $found
        } else {
            $config.ScheduledBackups
        }
    }

    process {
        if (-not $backupsToClean) {
            Write-Warning "No scheduled backups found in configuration."
            return $null
        }

        Write-Log -Message "=== FileGuardian Retention Cleanup Started ===" -Level Info

        foreach ($backup in $backupsToClean) {
            if (-not $backup.Enabled) {
                Write-Verbose "Skipping disabled backup: $($backup.Name)"
                continue
            }

            $retentionDays = if ($backup.RetentionDays) { $backup.RetentionDays } elseif ($config.BackupSettings.RetentionDays) { $config.BackupSettings.RetentionDays } else { Write-Warning "No RetentionDays configured for backup: $($backup.Name)"; continue }

            $backupDirectory = if ($backup.BackupPath) { $backup.BackupPath } elseif ($config.BackupSettings.DestinationPath) { $config.BackupSettings.DestinationPath } else { Write-Warning "No backup directory configured for: $($backup.Name)"; continue }

            if (-not (Test-Path $backupDirectory)) {
                Write-Warning "Backup directory not found: $backupDirectory"
                continue
            }

            Write-Log -Message "Checking retention for: $($backup.Name) (Directory: $backupDirectory, RetentionDays: $retentionDays)" -Level Info

            try {
                $result = Invoke-BackupRetention -BackupDirectory $backupDirectory -RetentionDays $retentionDays -BackupName $backup.Name

                if ($result -and $result.DeletedCount -gt 0) {
                    Write-Log -Message "Cleaned up $($result.DeletedCount) old backup(s) for $($backup.Name), freed $($result.FreedSpaceMB) MB" -Level Success
                } else {
                    Write-Log -Message "No old backups to clean up for $($backup.Name)" -Level Info
                }
            }
            catch {
                Write-Log -Message "Failed to clean up backups for $($backup.Name): $_" -Level Error
            }
        }

        Write-Log -Message "=== FileGuardian Retention Cleanup Finished ===" -Level Info
    }
}