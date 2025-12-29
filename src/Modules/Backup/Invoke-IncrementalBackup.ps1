function Invoke-IncrementalBackup {
    <#
    .SYNOPSIS
        Performs an incremental backup of modified files only.
    
    .DESCRIPTION
        Creates a backup containing only files that have been modified since the last backup
        (either full or incremental). Uses the integrity state tracking system to detect changes
        by comparing file hashes. This is efficient for frequent backups with few changes.
        
        Requires a previous backup state (latest.json) to exist. If no previous state is found,
        automatically performs a full backup instead.
    
    .PARAMETER SourcePath
        The source directory or file to backup. Required parameter.
    
    .PARAMETER DestinationPath
        The destination directory where the backup will be stored. If not specified, uses config file.
    
    .PARAMETER ConfigPath
        Path to the configuration file. Defaults to config/backup-config.json
    
    .PARAMETER BackupName
        Optional name for the backup. Defaults to "IncrementalBackup_YYYYMMDD_HHMMSS"
    
    .PARAMETER Compress
        If specified, the backup will be compressed into a ZIP archive. If not specified, uses config file setting.
    
    .PARAMETER ExcludePatterns
        Array of file patterns to exclude from backup (e.g., "*.tmp", "*.log"). If not specified, uses config file.
    
    .PARAMETER ReportFormat
        Format for the backup report. Default is JSON. Supported: JSON, HTML (future).
    
    .EXAMPLE
        Invoke-IncrementalBackup -SourcePath "C:\Data"
        Backs up only changed files since last backup, or automatically performs full backup if none exists
    
    .EXAMPLE
        Invoke-IncrementalBackup -SourcePath "C:\Data" -DestinationPath "D:\Backups" -Compress
        Incremental backup with custom destination and compression
    
    .NOTES
        - If no previous backup state exists, automatically performs a full backup first
        - Reports are always generated and digitally signed
        - Backup chain: Full -> Incremental -> Incremental -> Incremental -> Full (recommended)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ 
            if (Test-Path $_) { $true } 
            else { throw "Source path does not exist: $_" }
        })]
        [string]$SourcePath,
        
        [Parameter()]
        [string]$DestinationPath,
        
        [Parameter()]
        [string]$ConfigPath,
        
        [Parameter()]
        [string]$BackupName = "IncrementalBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
        
        [Parameter()]
        [switch]$Compress,
        
        [Parameter()]
        [string[]]$ExcludePatterns,
        
        [Parameter()]
        [ValidateSet("JSON", "HTML", "CSV")]
        [string]$ReportFormat = "JSON",
        
        [Parameter()]
        [string]$ReportPath
    )
    
    begin {
        # Load and initialize configuration
        $configResult = Initialize-BackupConfiguration -ConfigPath $ConfigPath -DestinationPath $DestinationPath -Compress $Compress -ExcludePatterns $ExcludePatterns -ReportFormat $ReportFormat -ReportOutputPath $ReportPath -BoundParameters $PSBoundParameters
        
        $DestinationPath = $configResult.DestinationPath
        $Compress = $configResult.Compress
        $ExcludePatterns = $configResult.ExcludePatterns
        
        # Use config values if not explicitly provided
        if (-not $PSBoundParameters.ContainsKey('ReportFormat') -and $configResult.ReportFormat) {
            $ReportFormat = $configResult.ReportFormat
        }
        if (-not $PSBoundParameters.ContainsKey('ReportPath') -and $configResult.ReportOutputPath) {
            $ReportPath = $configResult.ReportOutputPath
        }
        
        # Add timestamp to backup name if custom name was provided
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        if ($PSBoundParameters.ContainsKey('BackupName')) {
            $BackupName = "${BackupName}_$timestamp"
        }
        
        $backupDestination = Join-Path $DestinationPath $BackupName
        
        # Check if previous state exists
        $stateDir = Join-Path $DestinationPath "states"
        $latestStateFile = Join-Path $stateDir "latest.json"
        
        $script:performFullBackupFallback = -not (Test-Path $latestStateFile)
        
        if ($script:performFullBackupFallback) {
            Write-Log -Message "No previous backup state found. Performing full backup instead." -Level Warning
        }
        

        Write-Log -Message "Starting incremental backup from '$SourcePath' to '$backupDestination'" -Level Info
    }
    
    process {
        try {
            # Record start time for duration calculation
            $startTime = Get-Date

            # Create destination directory if it doesn't exist
            if (-not (Test-Path $DestinationPath)) {
                Write-Verbose "Creating destination directory: $DestinationPath"
                New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            }
            
            # Load previous state
            Write-Log -Message "Loading previous backup state from: $latestStateFile" -Level Info
            $previousState = Get-Content -Path $latestStateFile -Raw | ConvertFrom-Json
            
            # Check if source path matches
            $currentSourcePath = (Resolve-Path $SourcePath).Path
            if ($previousState.SourcePath -and $previousState.SourcePath -ne $currentSourcePath) {
                Write-Log -Message "Source path mismatch! Previous: '$($previousState.SourcePath)', Current: '$currentSourcePath'. Performing full backup instead." -Level Warning
                $script:performFullBackupFallback = $true
            }
            
            # If source mismatch, delegate to full backup
            if ($script:performFullBackupFallback) {
                Write-Log -Message "Delegating to full backup due to missing or mismatched state" -Level Info
                
                $fullBackupParams = @{
                    SourcePath = $SourcePath
                    DestinationPath = $DestinationPath
                    BackupName = $BackupName.Replace("IncrementalBackup", "FullBackup")
                    Compress = $Compress
                    ExcludePatterns = $ExcludePatterns
                    ReportFormat = $ReportFormat
                }
                
                if ($ConfigPath) {
                    $fullBackupParams['ConfigPath'] = $ConfigPath
                }
                
                if ($ReportPath) {
                    $fullBackupParams['ReportPath'] = $ReportPath
                }
                
                Write-Log -Message "Executing full backup as fallback..." -Level Info
                return Invoke-FullBackup @fullBackupParams
            }
            
            # Create hash lookup for previous state (for fast comparison)
            $previousHashes = @{}
            foreach ($file in $previousState.Files) {
                $previousHashes[$file.RelativePath] = $file.Hash
            }
            
            Write-Log -Message "Previous state: $($previousState.FileCount) files, last backup at $($previousState.Timestamp)" -Level Info
            
            # Get current state of source files (heavy operation)
            Write-Log -Message "Scanning source directory and calculating hashes..." -Level Info
            Write-Progress -Activity "Hashing files" -Status "Calculating hashes..." -PercentComplete 0
            $currentFiles = Get-FileIntegrityHash -Path $SourcePath -Recurse
            Write-Progress -Activity "Hashing files" -Completed
            Write-Log -Message "Calculated current hashes: $($currentFiles.Count) files" -Level Info
            
            # Apply exclusions to current files
            if ($ExcludePatterns.Count -gt 0) {
                Write-Verbose "Applying exclusion patterns: $($ExcludePatterns -join ', ')"
                $filteredFiles = @()
                foreach ($file in $currentFiles) {
                    $excluded = $false
                    foreach ($pattern in $ExcludePatterns) {
                        if ($file.RelativePath -like $pattern) {
                            $excluded = $true
                            break
                        }
                    }
                    if (-not $excluded) {
                        $filteredFiles += $file
                    }
                }
                $currentFiles = $filteredFiles
            }
            
            # Identify changed and new files
            $changedFiles = @()
            $newFiles = @()
            $deletedFiles = @()
            
            foreach ($file in $currentFiles) {
                if ($previousHashes.ContainsKey($file.RelativePath)) {
                    # File existed before - check if changed
                    if ($previousHashes[$file.RelativePath] -ne $file.Hash) {
                        $changedFiles += $file
                        Write-Verbose "Changed: $($file.RelativePath)"
                    }
                }
                else {
                    # New file
                    $newFiles += $file
                    Write-Verbose "New: $($file.RelativePath)"
                }
            }
            
            # Check for deleted files (existed in previous state but not in current)
            $currentRelativePaths = $currentFiles | ForEach-Object { $_.RelativePath }
            foreach ($previousFile in $previousState.Files) {
                if ($previousFile.RelativePath -notin $currentRelativePaths) {
                    $deletedFiles += $previousFile.RelativePath
                    Write-Verbose "Deleted: $($previousFile.RelativePath)"
                }
            }
            
            # Files to backup = changed + new
            $filesToBackup = $changedFiles + $newFiles
            $totalFiles = $filesToBackup.Count
            
            if ($totalFiles -eq 0) {
                Write-Log -Message "No changes detected. Backup not needed." -Level Info
                $endTime = Get-Date
                $duration = $null
                if ($startTime) { $duration = $endTime - $startTime }

                return [PSCustomObject]@{
                    Type = "Incremental"
                    BackupName = $BackupName
                    SourcePath = $SourcePath
                    DestinationPath = $null
                    Timestamp = $timestamp
                    FilesBackedUp = 0
                    FilesChanged = 0
                    FilesNew = 0
                    FilesDeleted = $deletedFiles.Count
                    DeletedFiles = $deletedFiles
                    TotalSizeMB = 0
                    Compressed = $false
                    ChangesDetected = $false
                    IntegrityStateSaved = $false
                    Duration = $duration
                }
            }
            
            $totalSize = ($filesToBackup | Measure-Object -Property Size -Sum).Sum
            
            Write-Log -Message "Changes detected: $($changedFiles.Count) modified, $($newFiles.Count) new, $($deletedFiles.Count) deleted" -Level Info
            Write-Log -Message "Backing up $totalFiles files (Total size: $([Math]::Round($totalSize/1MB, 2)) MB)" -Level Info
            
            # Copy files to temporary or final destination (use unique temp folder to avoid collisions)
            $tempDir = Join-Path $env:TEMP ("FileGuardian_{0}_{1}" -f $timestamp, [IO.Path]::GetRandomFileName())
            $finalDestination = if ($Compress) { $tempDir } else { $backupDestination }
            
            New-Item -Path $finalDestination -ItemType Directory -Force | Out-Null
            
            $copiedFiles = 0
            foreach ($file in $filesToBackup) {
                $targetPath = Join-Path $finalDestination $file.RelativePath
                $targetDir = Split-Path $targetPath -Parent

                if (-not (Test-Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                }

                Copy-Item -Path $file.Path -Destination $targetPath -Force
                $copiedFiles++

                if ($copiedFiles % 50 -eq 0) {
                    $percent = if ($totalFiles -gt 0) { [math]::Round(($copiedFiles / $totalFiles) * 100, 0) } else { 100 }
                    Write-Verbose "Progress: $copiedFiles / $totalFiles files copied"
                    Write-Progress -Activity "Backing up" -Status "Copied $copiedFiles of $totalFiles" -PercentComplete $percent
                }
            }
            Write-Progress -Activity "Backing up" -Completed
            
            Write-Log -Message "Incremental backup completed successfully - $copiedFiles files copied" -Level Success
            
            # Save backup metadata for integrity verification BEFORE compression
            $metadataTargetPath = if ($Compress) { Join-Path $tempDir ".backup-metadata.json" } else { Join-Path $backupDestination ".backup-metadata.json" }
            Save-BackupMetadata -BackupType "Incremental" -SourcePath $SourcePath -Timestamp $timestamp -FilesBackedUp $copiedFiles -TargetPath $metadataTargetPath -BaseBackup $previousState.Timestamp
            Write-Log -Message "Backup metadata saved to: $metadataTargetPath" -Level Info
            
            # Handle compression or return direct copy info
            if ($Compress) {
                $zipPath = "$backupDestination.zip"
                Write-Verbose "Using Compress-Backup module for compression..."
                
                try {
                    $compressionResult = Compress-Backup -SourcePath $tempDir -DestinationPath $zipPath -CompressionLevel Optimal -RemoveSource -Verbose:$VerbosePreference
                    
                    $backupInfo = @{
                        Type = "Incremental"
                        BackupName = $BackupName
                        SourcePath = $SourcePath
                        DestinationPath = $zipPath
                        Timestamp = $timestamp
                        FilesBackedUp = $copiedFiles
                        FilesChanged = $changedFiles.Count
                        FilesNew = $newFiles.Count
                        FilesDeleted = $deletedFiles.Count
                        DeletedFiles = $deletedFiles
                        TotalSizeMB = $compressionResult.OriginalSizeMB
                        CompressedSizeMB = $compressionResult.CompressedSizeMB
                        CompressionRatio = $compressionResult.CompressionRatio
                        Compressed = $true
                        ChangesDetected = $true
                        BaseBackup = $previousState.Timestamp
                    }
                }
                catch {
                    # Clean up temp directory on error
                    if (Test-Path $tempDir) {
                        Remove-Item -Path $tempDir -Recurse -Force
                    }
                    throw
                }
            }
            else {
                $backupInfo = @{
                    Type = "Incremental"
                    BackupName = $BackupName
                    SourcePath = $SourcePath
                    DestinationPath = $backupDestination
                    Timestamp = $timestamp
                    FilesBackedUp = $copiedFiles
                    FilesChanged = $changedFiles.Count
                    FilesNew = $newFiles.Count
                    FilesDeleted = $deletedFiles.Count
                    DeletedFiles = $deletedFiles
                    TotalSizeMB = [Math]::Round($totalSize/1MB, 2)
                    Compressed = $false
                    ChangesDetected = $true
                    BaseBackup = $previousState.Timestamp
                }
            }
            
            # Always save integrity state (update to reflect current state)
            $backupInfo['IntegrityStateSaved'] = Invoke-IntegrityStateSave -SourcePath $SourcePath -DestinationPath $DestinationPath -BackupName $backupInfo.DestinationPath -Compress $Compress
            if ($backupInfo['IntegrityStateSaved']) {
                Write-Log -Message "Integrity state saved for backup" -Level Info
            } else {
                Write-Log -Message "Integrity state NOT saved for backup" -Level Warning
            }
            
            # Verify previous backups integrity
            $verificationResult = Test-PreviousBackups -BackupDestination $backupInfo.DestinationPath -SourcePath $SourcePath -Compress $Compress
            $backupInfo['PreviousBackupsVerified'] = $verificationResult.VerifiedCount
            $backupInfo['CorruptedBackups'] = $verificationResult.CorruptedBackups
            $backupInfo['VerifiedBackupsOK'] = $verificationResult.VerifiedBackupsOK
            Write-Log -Message "Previous backups verification: Checked $($verificationResult.VerifiedCount), Corrupted $($verificationResult.CorruptedBackups.Count)" -Level Info
            
            # Calculate duration and generate report (ALWAYS - this is mandatory)
            $endTime = Get-Date
            if ($startTime) {
                $backupInfo['Duration'] = $endTime - $startTime
            }


            $backupInfo = New-BackupReport -BackupInfo $backupInfo -ReportFormat $ReportFormat -ReportPath $ReportPath
            
            return [PSCustomObject]$backupInfo
        }
        catch {
            Write-Error "Incremental backup failed: $_"
            throw
        }
        finally {
            # Ensure temporary directory is removed if it exists (cleanup on errors or if compression didn't remove it)
            if ($Compress -and $tempDir -and (Test-Path $tempDir)) {
                try { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction Stop } catch { Write-Log -Message ("Failed to cleanup tempDir: {0}. {1}" -f $tempDir, $_.Exception.Message) -Level Warning }
            }
        }
    }
}