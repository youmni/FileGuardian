<#
.SYNOPSIS
    Standalone retention cleanup script for scheduled task execution.

.DESCRIPTION
    This script is triggered automatically after each backup task completes.
    It reads the backup configuration and removes old backups based on RetentionDays.

.PARAMETER BackupName
    Optional backup name to clean up. If not specified, cleans all backups in config.

.PARAMETER ConfigPath
    Path to the configuration file. Defaults to config/backup-config.json

.EXAMPLE
    .\Invoke-RetentionCleanup.ps1 -BackupName "colruyt"
    Cleans up old backups for the "colruyt" backup configuration

.EXAMPLE
    .\Invoke-RetentionCleanup.ps1
    Cleans up old backups for all configured backups
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$BackupName,
    
    [Parameter()]
    [string]$ConfigPath = "$PSScriptRoot\..\config\backup-config.json"
)

# Get script directory and import FileGuardian module
$projectRoot = Split-Path $PSScriptRoot -Parent
$moduleManifest = Join-Path $projectRoot "src\FileGuardian.psd1"

if (-not (Test-Path $moduleManifest)) {
    Write-Error "FileGuardian module not found at: $moduleManifest"
    exit 1
}

try {
    Import-Module $moduleManifest -Force -ErrorAction Stop
    
    # Read configuration
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        exit 1
    }
    
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    
    # Determine which backups to clean up
    $backupsToClean = if ($BackupName) {
        $found = $config.ScheduledBackups | Where-Object { $_.Name -eq $BackupName }
        if (-not $found) {
            Write-Warning "Backup '$BackupName' not found in configuration."
            exit 0
        }
        $found
    } else {
        $config.ScheduledBackups
    }
    
    if (-not $backupsToClean) {
        Write-Warning "No scheduled backups found in configuration."
        exit 0
    }
    
    Write-Log -Message "=== FileGuardian Retention Cleanup Started ===" -Level Info
    
    # Process each backup configuration
    foreach ($backup in $backupsToClean) {
        if (-not $backup.Enabled) {
            Write-Verbose "Skipping disabled backup: $($backup.Name)"
            continue
        }
        
        # Determine retention days (use backup-specific or global setting)
        $retentionDays = if ($backup.RetentionDays) {
            $backup.RetentionDays
        } elseif ($config.BackupSettings.RetentionDays) {
            $config.BackupSettings.RetentionDays
        } else {
            Write-Warning "No RetentionDays configured for backup: $($backup.Name)"
            continue
        }
        
        # Get backup directory
        $backupDirectory = if ($backup.BackupPath) {
            $backup.BackupPath
        } elseif ($config.BackupSettings.DestinationPath) {
            $config.BackupSettings.DestinationPath
        } else {
            Write-Warning "No backup directory configured for: $($backup.Name)"
            continue
        }
        
        if (-not (Test-Path $backupDirectory)) {
            Write-Warning "Backup directory not found: $backupDirectory"
            continue
        }
        
        Write-Log -Message "Checking retention for: $($backup.Name) (Directory: $backupDirectory, RetentionDays: $retentionDays)" -Level Info
        
        # Perform cleanup
        try {
            $result = Invoke-BackupRetention -BackupDirectory $backupDirectory -RetentionDays $retentionDays -BackupName $backup.Name
            
            if ($result.DeletedCount -gt 0) {
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
catch {
    Write-Error "Retention cleanup failed: $_"
    exit 1
}
