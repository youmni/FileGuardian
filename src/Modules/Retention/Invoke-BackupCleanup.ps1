function Invoke-BackupCleanup {
    <#
    .SYNOPSIS
        Perform retention cleanup for a named backup configuration.

    .DESCRIPTION
        Encapsulates the cleanup logic so the main orchestrator can delegate.

    .PARAMETER BackupName
        Name of the backup configuration to clean up.

    .PARAMETER ConfigPath
        Optional path to custom configuration file.

    .PARAMETER CleanupBackupDirectory
        Optional explicit backup directory to clean up.

    .PARAMETER RetentionDays
        Optional override for retention days.

    .PARAMETER Quiet
        Suppress informational output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$BackupName,

        [Parameter(Mandatory=$false)]
        [string]$ConfigPath,

        [Parameter(Mandatory=$false)]
        [string]$CleanupBackupDirectory,

        [Parameter(Mandatory=$false)]
        [int]$RetentionDays,

        [Parameter(Mandatory=$false)]
        [switch]$Quiet
    )

    begin {
        if ($Quiet) {
            $VerbosePreference = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
        }
    }

    process {
        try {
            if ($ConfigPath) {
                $config = Read-Config -ConfigPath $ConfigPath
            }
            else {
                $config = Read-Config
            }

            if (-not $config -or -not $config.ScheduledBackups) {
                throw "No scheduled backups found in configuration."
            }

            $backupConfig = $config.ScheduledBackups | Where-Object { $_.Name -eq $BackupName }
            if (-not $backupConfig) {
                throw "Backup '$BackupName' not found in configuration."
            }

            $days = if ($PSBoundParameters.ContainsKey('RetentionDays')) {
                $RetentionDays
            } elseif ($backupConfig.RetentionDays) {
                $backupConfig.RetentionDays
            } elseif ($config.BackupSettings.RetentionDays) {
                $config.BackupSettings.RetentionDays
            } else {
                throw "No RetentionDays configured for backup: $BackupName"
            }

            $backupDir = if ($PSBoundParameters.ContainsKey('CleanupBackupDirectory')) {
                $CleanupBackupDirectory
            } elseif ($backupConfig.BackupPath) {
                $backupConfig.BackupPath
            } elseif ($config.BackupSettings.DestinationPath) {
                $config.BackupSettings.DestinationPath
            } else {
                throw "No backup directory configured for: $BackupName"
            }

            if (-not (Test-Path $backupDir)) {
                throw "Backup directory not found: $backupDir"
            }

            Write-Log -Message "Cleaning up backups in: $backupDir (RetentionDays: $days)" -Level Info

            $result = Invoke-BackupRetention -BackupDirectory $backupDir -RetentionDays $days -BackupName $BackupName

            if ($result -and $result.DeletedCount -gt 0) {
                Write-Log -Message "Cleanup completed: Deleted $($result.DeletedCount) backup(s), freed $($result.FreedSpaceMB) MB" -Level Success
            } else {
                Write-Log -Message "Cleanup completed: No backups exceeded retention period" -Level Info
            }

            return $result
        }
        catch {
            Write-Log -Message "ERROR (Invoke-BackupCleanup): $($_.Exception.Message)" -Level Error
            throw
        }
    }
}
