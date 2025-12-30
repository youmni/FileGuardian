function Invoke-BackupRetention {
    <#
    .SYNOPSIS
        Cleans up old backups based on retention policy.
    
    .DESCRIPTION
        Removes backups older than the specified retention period.
        Supports both compressed (ZIP) and uncompressed backups.
        Automatically called after each backup operation.
    
    .PARAMETER BackupDirectory
        The directory containing backups to check.
    
    .PARAMETER RetentionDays
        Number of days to keep backups. Backups older than this are deleted.
    
    .PARAMETER BackupName
        Optional backup name pattern to filter which backups to clean up.
        If not specified, cleans all backups in the directory.
    
    .EXAMPLE
        Invoke-BackupRetention -BackupDirectory "C:\Backups" -RetentionDays 30
        Removes all backups older than 30 days
    
    .EXAMPLE
        Invoke-BackupRetention -BackupDirectory "C:\Backups" -RetentionDays 90 -BackupName "ProjectA"
        Removes ProjectA backups older than 90 days
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$BackupDirectory,
        
        [Parameter(Mandatory = $true)]
        [int]$RetentionDays,
        
        [Parameter(Mandatory = $false)]
        [string]$BackupName = $null
    )
    
    begin {
        Write-Log -Message "Starting retention cleanup (RetentionDays: $RetentionDays)..." -Level Info
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $deletedCount = 0
        $freedSpace = 0
    }
    
    process {
        try {
            # Get all backups (directories and ZIP files)
            $allBackups = @()
            
            # Get backup directories
            $backupDirs = Get-ChildItem -Path $BackupDirectory -Directory | 
                Where-Object { $_.Name -ne "states" }
            
            # Get backup ZIP files
            $backupZips = Get-ChildItem -Path $BackupDirectory -File -Filter "*.zip"
            
            # Combine both
            $allBackups = @($backupDirs) + @($backupZips)
            
            # Filter by backup name pattern if specified
            if ($BackupName) {
                $allBackups = $allBackups | Where-Object { $_.Name -like "$BackupName*" }
            }
            
            if ($allBackups.Count -eq 0) {
                Write-Log -Message "No backups found to check for retention" -Level Info
                return [PSCustomObject]@{
                    DeletedCount = 0
                    FreedSpaceMB = 0
                    CutoffDate = $cutoffDate
                }
            }
            
            Write-Verbose "Found $($allBackups.Count) backups to check"

            # Safety: never delete if ALL backups would be deleted (possible system clock issue)
            $backupsToDelete = $allBackups | Where-Object { $_.CreationTime -lt $cutoffDate }
            if ($backupsToDelete.Count -eq $allBackups.Count -and $allBackups.Count -gt 0) {
                Write-Log -Message "SAFETY: Refusing to delete ALL backups. Check system clock and retention settings." -Level Error
                return [PSCustomObject]@{
                    DeletedCount = 0
                    FreedSpaceMB = 0
                    CutoffDate = $cutoffDate
                    RetentionDays = $RetentionDays
                }
            }
            
            # Check each backup
            foreach ($backup in $allBackups) {
                $backupAge = (Get-Date) - $backup.CreationTime
                
                if ($backup.CreationTime -lt $cutoffDate) {
                    # Backup is older than retention period
                    $backupSize = if ($backup.PSIsContainer) {
                        # Directory - calculate total size
                        (Get-ChildItem -Path $backup.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
                    } else {
                        # ZIP file
                        $backup.Length
                    }
                    
                    $ageDays = [math]::Round($backupAge.TotalDays, 1)
                    Write-Log -Message "Deleting old backup: $($backup.Name) (Age: $ageDays days, Size: $([math]::Round($backupSize/1MB, 2)) MB)" -Level Warning
                    
                    try {
                        Remove-Item -Path $backup.FullName -Recurse -Force -ErrorAction Stop
                        $deletedCount++
                        $freedSpace += $backupSize
                        Write-Verbose "Deleted: $($backup.Name)"
                    }
                    catch {
                        Write-Log -Message "Failed to delete backup $($backup.Name): $_" -Level Error
                    }
                }
                else {
                    Write-Verbose "Keeping backup: $($backup.Name) (Age: $([math]::Round($backupAge.TotalDays, 1)) days)"
                }
            }
            
            # Clean up old state files that correspond to deleted backups
            $statesDir = Join-Path $BackupDirectory "states"
            if (Test-Path $statesDir) {
                $stateFiles = Get-ChildItem -Path $statesDir -File -Filter "*.json" | 
                    Where-Object { $_.Name -ne "latest.json" -and $_.Name -ne "prev.json" }
                
                foreach ($stateFile in $stateFiles) {
                    $stateBaseName = $stateFile.BaseName
                    $correspondingBackup = $allBackups | Where-Object { $_.Name -eq $stateBaseName -or $_.BaseName -eq $stateBaseName }
                    
                    if (-not $correspondingBackup -and $stateFile.CreationTime -lt $cutoffDate) {
                        Write-Verbose "Deleting orphaned state file: $($stateFile.Name)"
                        Remove-Item -Path $stateFile.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            if ($deletedCount -gt 0) {
                Write-Log -Message "Retention cleanup completed: Deleted $deletedCount backup(s), freed $([math]::Round($freedSpace/1MB, 2)) MB" -Level Success
            }
            else {
                Write-Log -Message "Retention cleanup completed: No backups exceeded retention period" -Level Info
            }
            
            return [PSCustomObject]@{
                DeletedCount = $deletedCount
                FreedSpaceMB = [math]::Round($freedSpace/1MB, 2)
                CutoffDate = $cutoffDate
                RetentionDays = $RetentionDays
            }
        }
        catch {
            Write-Log -Message "Retention cleanup failed: $_" -Level Error
            throw
        }
    }
}
