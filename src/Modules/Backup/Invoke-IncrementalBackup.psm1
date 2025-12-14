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
        # Import Read-Config module
        $configModule = Join-Path $PSScriptRoot "..\Config\Read-Config.psm1"
        Import-Module $configModule -Force
        
        # Load configuration
        try {
            $config = if ($ConfigPath) {
                Read-Config -ConfigPath $ConfigPath
            } else {
                Read-Config -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Log -Message "Could not load config file: $_. Using parameters only." -Level Warning
            $config = $null
        }
        
        # Apply config defaults for destination if not specified
        if (-not $DestinationPath) {
            if ($config -and $config.BackupSettings.DestinationPath) {
                $DestinationPath = $config.BackupSettings.DestinationPath
                Write-Verbose "Using DestinationPath from config: $DestinationPath"
            }
            else {
                throw "DestinationPath is required. Specify it as a parameter or in the config file."
            }
        }
        
        # Use config for compression if not explicitly specified
        if (-not $PSBoundParameters.ContainsKey('Compress') -and $config -and $config.BackupSettings.CompressBackups) {
            $Compress = $config.BackupSettings.CompressBackups
            Write-Verbose "Using Compress setting from config: $Compress"
        }
        
        # Use config for exclusion patterns if not specified
        if (-not $ExcludePatterns -and $config -and $config.BackupSettings.ExcludePatterns) {
            $ExcludePatterns = $config.BackupSettings.ExcludePatterns
            Write-Verbose "Using ExcludePatterns from config: $($ExcludePatterns -join ', ')"
        }
        
        if (-not $ExcludePatterns) {
            $ExcludePatterns = @()
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
        
        # Set flag for full backup fallback
        $script:performFullBackupFallback = -not (Test-Path $latestStateFile)
        
        if ($script:performFullBackupFallback) {
            Write-Log -Message "No previous backup state found. Performing full backup instead." -Level Warning
        }
        
        # Import Compress-Backup module if compression is needed
        if ($Compress) {
            $compressModule = Join-Path $PSScriptRoot "Compress-Backup.psm1"
            if (Test-Path $compressModule) {
                Import-Module $compressModule -Force
            }
            else {
                throw "Compress-Backup module not found at: $compressModule"
            }
        }
        
        Write-Log -Message "Starting incremental backup from '$SourcePath' to '$backupDestination'" -Level Info
    }
    
    process {
        try {
            # If no previous state, delegate to full backup
            if ($script:performFullBackupFallback) {
                $fullBackupModule = Join-Path $PSScriptRoot "Invoke-FullBackup.psm1"
                Import-Module $fullBackupModule -Force
                
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
                
                return Invoke-FullBackup @fullBackupParams
            }
            
            # Create destination directory if it doesn't exist
            if (-not (Test-Path $DestinationPath)) {
                Write-Verbose "Creating destination directory: $DestinationPath"
                New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            }
            
            # Load previous state
            Write-Log -Message "Loading previous backup state from: $latestStateFile" -Level Info
            $previousState = Get-Content -Path $latestStateFile -Raw | ConvertFrom-Json
            
            # Create hash lookup for previous state (for fast comparison)
            $previousHashes = @{}
            foreach ($file in $previousState.Files) {
                $previousHashes[$file.RelativePath] = $file.Hash
            }
            
            Write-Log -Message "Previous state: $($previousState.FileCount) files, last backup at $($previousState.Timestamp)" -Level Info
            
            # Import Get-FileIntegrityHash module
            $integrityModule = Join-Path $PSScriptRoot "..\Integrity\Get-FileIntegrityHash.psm1"
            Import-Module $integrityModule -Force
            
            # Get current state of source files
            Write-Log -Message "Scanning source directory and calculating hashes..." -Level Info
            $currentFiles = Get-FileIntegrityHash -Path $SourcePath -Recurse
            
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
                }
            }
            
            $totalSize = ($filesToBackup | Measure-Object -Property Size -Sum).Sum
            
            Write-Log -Message "Changes detected: $($changedFiles.Count) modified, $($newFiles.Count) new, $($deletedFiles.Count) deleted" -Level Info
            Write-Log -Message "Backing up $totalFiles files (Total size: $([Math]::Round($totalSize/1MB, 2)) MB)" -Level Info
            
            # Copy files to temporary or final destination
            $tempDir = Join-Path $env:TEMP "FileGuardian_$timestamp"
            $finalDestination = if ($Compress) { $tempDir } else { $backupDestination }
            
            New-Item -Path $finalDestination -ItemType Directory -Force | Out-Null
            
            # Resolve source path to absolute
            $absoluteSourcePath = (Resolve-Path $SourcePath).Path
            
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
                    Write-Verbose "Progress: $copiedFiles / $totalFiles files copied"
                }
            }
            
            Write-Log -Message "Incremental backup completed successfully - $copiedFiles files copied" -Level Success
            
            # Save backup metadata for integrity verification BEFORE compression
            try {
                $metadataTargetPath = if ($Compress) { Join-Path $tempDir ".backup-metadata.json" } else { Join-Path $backupDestination ".backup-metadata.json" }
                $metadata = @{
                    BackupType = "Incremental"
                    SourcePath = (Resolve-Path $SourcePath).Path
                    Timestamp = $timestamp
                    BaseBackup = $previousState.Timestamp
                    FilesBackedUp = $copiedFiles
                }
                $metadata | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataTargetPath -Encoding UTF8
                Write-Verbose "Backup metadata saved: $metadataTargetPath"
            }
            catch {
                Write-Warning "Failed to save backup metadata: $_"
            }
            
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
            try {
                Write-Log -Message "Updating integrity state..." -Level Info
                $saveStateModule = Join-Path $PSScriptRoot "..\Integrity\Save-IntegrityState.psm1"
                if (Test-Path $saveStateModule) {
                    Import-Module $saveStateModule -Force
                    # Determine backup name for state file
                    $stateBackupName = if ($Compress) {
                        (Get-Item $backupInfo.DestinationPath).BaseName
                    } else {
                        Split-Path $backupInfo.DestinationPath -Leaf
                    }
                    Save-IntegrityState -SourcePath $SourcePath -StateDirectory $stateDir -BackupName $stateBackupName
                    $backupInfo['IntegrityStateSaved'] = $true
                }
                else {
                    Write-Warning "Save-IntegrityState module not found. Integrity state not saved."
                    $backupInfo['IntegrityStateSaved'] = $false
                }
            }
            catch {
                Write-Warning "Failed to save integrity state: $_"
                $backupInfo['IntegrityStateSaved'] = $false
            }
            
            # Verify previous backups integrity
            try {
                Write-Log -Message "Verifying previous backups integrity..." -Level Info
                $testIntegrityModule = Join-Path $PSScriptRoot "..\Integrity\Test-BackupIntegrity.psm1"
                
                if (Test-Path $testIntegrityModule) {
                    Import-Module $testIntegrityModule -Force
                    
                    # Find all previous backups in the destination path
                    $backupDir = if ($Compress) { Split-Path $backupInfo.DestinationPath -Parent } else { Split-Path $backupInfo.DestinationPath -Parent }
                    $previousBackups = @()
                    $corruptedBackups = @()
                    $verifiedBackups = @()
                    
                    # Normalize current source path for comparison
                    $normalizedCurrentSource = (Resolve-Path $SourcePath).Path
                    
                    if (Test-Path $backupDir) {
                        # Get all backup directories and ZIP files (exclude current backup and states folder)
                        $currentBackupName = if ($Compress) { Split-Path $backupInfo.DestinationPath -Leaf } else { Split-Path $backupInfo.DestinationPath -Leaf }
                        $allBackupDirs = Get-ChildItem -Path $backupDir -Directory | Where-Object { $_.Name -ne "states" -and $_.Name -ne $currentBackupName }
                        $allBackupZips = Get-ChildItem -Path $backupDir -File -Filter "*.zip" | Where-Object { $_.Name -ne $currentBackupName }
                        $allBackups = @($allBackupDirs) + @($allBackupZips)
                        
                        foreach ($backup in $allBackups) {
                            try {
                                # Verify all backups in the destination folder, regardless of source
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
                    
                    $backupInfo['PreviousBackupsVerified'] = $verifiedBackups.Count + $corruptedBackups.Count
                    $backupInfo['CorruptedBackups'] = $corruptedBackups
                    $backupInfo['VerifiedBackupsOK'] = $verifiedBackups.Count
                    
                    if ($corruptedBackups.Count -gt 0) {
                        Write-Log -Message "WARNING: Found $($corruptedBackups.Count) corrupted previous backup(s)!" -Level Warning
                    }
                    else {
                        Write-Log -Message "All previous backups verified successfully ($($verifiedBackups.Count) checked)" -Level Info
                    }
                }
                else {
                    $backupInfo['PreviousBackupsVerified'] = 0
                    $backupInfo['CorruptedBackups'] = @()
                }
            }
            catch {
                Write-Warning "Failed to verify previous backups: $_"
                $backupInfo['PreviousBackupsVerified'] = 0
                $backupInfo['CorruptedBackups'] = @()
            }
            
            # Generate report (ALWAYS - this is mandatory)
            try {
                Write-Log -Message "Generating backup report ($ReportFormat)..." -Level Info
                $signModule = Join-Path $PSScriptRoot "..\Reporting\Protect-Report.psm1"
                
                # Select report module based on format
                $reportModule = switch ($ReportFormat) {
                    "JSON" { Join-Path $PSScriptRoot "..\Reporting\Write-JsonReport.psm1" }
                    "HTML" { Join-Path $PSScriptRoot "..\Reporting\Write-HtmlReport.psm1" }
                    "CSV"  { Join-Path $PSScriptRoot "..\Reporting\Write-CsvReport.psm1" }
                    default { Join-Path $PSScriptRoot "..\Reporting\Write-JsonReport.psm1" }
                }
                
                if (Test-Path $reportModule) {
                    Import-Module $reportModule -Force
                    
                    # Generate report (ALWAYS)
                    $reportInfo = if ($ReportFormat -eq "JSON") {
                        if ($ReportPath) {
                            Write-JsonReport -BackupInfo ([PSCustomObject]$backupInfo) -ReportPath $ReportPath
                        } else {
                            Write-JsonReport -BackupInfo ([PSCustomObject]$backupInfo)
                        }
                    }
                    elseif ($ReportFormat -eq "HTML") {
                        if ($ReportPath) {
                            Write-HtmlReport -BackupInfo ([PSCustomObject]$backupInfo) -ReportPath $ReportPath
                        } else {
                            Write-HtmlReport -BackupInfo ([PSCustomObject]$backupInfo)
                        }
                    }
                    elseif ($ReportFormat -eq "CSV") {
                        if ($ReportPath) {
                            Write-CsvReport -BackupInfo ([PSCustomObject]$backupInfo) -ReportPath $ReportPath
                        } else {
                            Write-CsvReport -BackupInfo ([PSCustomObject]$backupInfo)
                        }
                    }
                    
                    if ($reportInfo -and $reportInfo.ReportPath) {
                        $backupInfo['ReportPath'] = $reportInfo.ReportPath
                        $backupInfo['ReportFormat'] = $ReportFormat
                        Write-Log -Message "Report generated: $($reportInfo.ReportPath)" -Level Success
                        
                        # Sign report (mandatory)
                        if (Test-Path $signModule) {
                            Import-Module $signModule -Force
                            $signInfo = Protect-Report -ReportPath $reportInfo.ReportPath
                            $backupInfo['ReportSigned'] = $true
                            $backupInfo['ReportSignature'] = $signInfo.Hash
                            Write-Log -Message "Report signed successfully" -Level Info
                        }
                    }
                }
                else {
                    Write-Log -Message "Report module not found: $reportModule" -Level Error
                    $backupInfo['ReportPath'] = $null
                    $backupInfo['ReportSigned'] = $false
                }
            }
            catch {
                Write-Log -Message "Failed to generate report: $_" -Level Error
                $backupInfo['ReportPath'] = $null
                $backupInfo['ReportSigned'] = $false
            }
            
            return [PSCustomObject]$backupInfo
        }
        catch {
            Write-Error "Incremental backup failed: $_"
            throw
        }
    }
}