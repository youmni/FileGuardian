function Test-PreviousBackups {
    <#
    .SYNOPSIS
        Verifies integrity of all previous backups.
    
    .DESCRIPTION
        Helper function that tests the integrity of all previous backups in the
        destination directory. Returns information about corrupted and verified backups.
    
    .PARAMETER BackupDestination
        The path to the backup (current backup being created).
    
    .PARAMETER SourcePath
        The source path that was backed up (for verification).
    
    .PARAMETER Compress
        Whether the backup was compressed.
    
    .OUTPUTS
        PSCustomObject with verification results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupDestination,
        
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter()]
        [bool]$Compress
    )
    
    try {
        Write-Log -Message "Verifying previous backups integrity..." -Level Info
        $testIntegrityModule = Join-Path $PSScriptRoot "..\Integrity\Test-BackupIntegrity.psm1"
        
        if (-not (Test-Path $testIntegrityModule)) {
            return [PSCustomObject]@{
                VerifiedCount = 0
                CorruptedBackups = @()
                VerifiedBackupsOK = 0
            }
        }
        
        Import-Module $testIntegrityModule -Force
        
        # Find all previous backups in the destination path
        $backupDir = if ($Compress) { 
            Split-Path $BackupDestination -Parent 
        } else { 
            Split-Path $BackupDestination -Parent 
        }
        
        $corruptedBackups = @()
        $verifiedBackups = @()
        
        # Normalize current source path for comparison
        $normalizedCurrentSource = (Resolve-Path $SourcePath).Path
        
        if (Test-Path $backupDir) {
            # Get all backup directories and ZIP files (exclude current backup and states folder)
            $currentBackupName = if ($Compress) { 
                Split-Path $BackupDestination -Leaf 
            } else { 
                Split-Path $BackupDestination -Leaf 
            }
            
            $allBackupDirs = Get-ChildItem -Path $backupDir -Directory | 
                Where-Object { $_.Name -ne "states" -and $_.Name -ne $currentBackupName }
            $allBackupZips = Get-ChildItem -Path $backupDir -File -Filter "*.zip" | 
                Where-Object { $_.Name -ne $currentBackupName }
            $allBackups = @($allBackupDirs) + @($allBackupZips)
            
            foreach ($backup in $allBackups) {
                try {
                    # Verify all backups in the destination folder
                    $verifyResult = Test-BackupIntegrity -BackupPath $backup.FullName
                    
                    if ($verifyResult -and -not $verifyResult.IsIntact) {
                        # Get lists of corrupted and missing files
                        $corruptedFilesList = if ($verifyResult.Corrupted) {
                            @($verifyResult.Corrupted | ForEach-Object { $_.Path } | Where-Object { $_ })
                        } else { @() }
                        
                        $missingFilesList = if ($verifyResult.Missing) {
                            @($verifyResult.Missing | ForEach-Object { $_.RelativePath } | Where-Object { $_ })
                        } else { @() }
                        
                        $corruptedBackups += [PSCustomObject]@{
                            BackupName = $backup.Name
                            BackupPath = $backup.FullName
                            CorruptedFiles = $verifyResult.Summary.CorruptedCount
                            MissingFiles = $verifyResult.Summary.MissingCount
                            TotalIssues = $verifyResult.Summary.CorruptedCount + $verifyResult.Summary.MissingCount
                            CorruptedFilesList = $corruptedFilesList
                            MissingFilesList = $missingFilesList
                        }
                        Write-Log -Message "Previous backup is CORRUPTED: $($backup.Name) ($($verifyResult.Summary.CorruptedCount) corrupted, $($verifyResult.Summary.MissingCount) missing)" -Level Warning
                    }
                    else {
                        $verifiedBackups += $backup.Name
                    }
                }
                catch {
                    Write-Verbose "Could not verify backup: $($backup.Name) - $_"
                }
            }
        }
        
        if ($corruptedBackups.Count -gt 0) {
            Write-Log -Message "WARNING: Found $($corruptedBackups.Count) corrupted previous backup(s)!" -Level Warning
        }
        else {
            Write-Log -Message "All previous backups verified successfully ($($verifiedBackups.Count) checked)" -Level Info
        }
        
        return [PSCustomObject]@{
            VerifiedCount = $verifiedBackups.Count + $corruptedBackups.Count
            CorruptedBackups = $corruptedBackups
            VerifiedBackupsOK = $verifiedBackups.Count
        }
    }
    catch {
        Write-Warning "Failed to verify previous backups: $_"
        return [PSCustomObject]@{
            VerifiedCount = 0
            CorruptedBackups = @()
            VerifiedBackupsOK = 0
        }
    }
}