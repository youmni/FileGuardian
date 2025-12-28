function Invoke-FileGuardian {
    <#
    .SYNOPSIS
        Unified command for FileGuardian backup operations.
    
    .DESCRIPTION
        Main entry point for FileGuardian functionality. Supports backup operations,
        integrity verification, reporting, scheduling, and cleanup through a single command interface.
    
    .PARAMETER Action
        The operation to perform. Valid values: 'Backup', 'Verify', 'Report', 'Restore', 'Schedule', 'Cleanup'.
    
    .EXAMPLE
        Invoke-FileGuardian -Action Backup -SourcePath "C:\Data"
    
    .EXAMPLE
        Invoke-FileGuardian -Action Schedule
    
    .EXAMPLE
        Invoke-FileGuardian -Action Schedule -BackupName "DailyDocuments"
    
    .EXAMPLE
        Invoke-FileGuardian -Action Cleanup -BackupName "MyBackup"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet('Backup', 'Verify', 'Report', 'Restore', 'Schedule', 'Cleanup')]
        [string]$Action,
        
        # Backup parameters
        [Parameter(Mandatory=$false)]
        [ValidateScript({ 
            if ($Action -eq 'Backup' -and -not (Test-Path $_)) {
                throw "Source path does not exist: $_"
            }
            $true
        })]
        [string]$SourcePath,

        # Restore parameters
        [Parameter(Mandatory=$false)]
        [ValidateScript({ 
            if ($Action -eq 'Restore' -and -not (Test-Path $_)) {
                throw "Backup directory does not exist: $_"
            }
            $true
        })]
        [string]$BackupDirectory,

        [Parameter(Mandatory=$false)]
        [string]$RestoreDirectory,
        
        # Cleanup parameters
        [Parameter(Mandatory=$false)]
        [string]$CleanupBackupDirectory,
        
        [Parameter(Mandatory=$false)]
        [string]$DestinationPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Full', 'Incremental')]
        [string]$BackupType = 'Full',
        
        # Verify backup parameters
        [Parameter(Mandatory=$false)]
        [ValidateScript({ 
            if ($Action -eq 'Verify' -and -not (Test-Path $_)) {
                throw "Backup path does not exist: $_"
            }
            $true
        })]
        [string]$BackupPath,
        
        # Report path for verification
        [Parameter(Mandatory=$false)]
        [ValidateScript({ 
            if ($Action -eq 'Report' -and -not (Test-Path $_)) {
                throw "Report path does not exist: $_"
            }
            $true
        })]
        [string]$ReportPath,
        
        # Report output path for backups
        [Parameter(Mandatory=$false)]
        [string]$ReportOutputPath,
        
        [Parameter(Mandatory=$false)]
        [string]$BackupName,
        
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory=$false)]
        [switch]$Compress,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExcludePatterns,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('JSON', 'HTML', 'CSV')]
        [string]$ReportFormat,
        
        # Schedule parameters
        [Parameter(Mandatory=$false)]
        [switch]$Remove,
        
        # Cleanup parameters
        [Parameter(Mandatory=$false)]
        [int]$RetentionDays,
        
        [Parameter(Mandatory=$false)]
        [switch]$Quiet
    )
    
    begin {
        # Validate required parameters based on Action
        switch ($Action) {
            'Backup' {
                if (-not $SourcePath) {
                    throw "SourcePath is required for Backup action"
                }
            }
            'Verify' {
                if (-not $BackupPath) {
                    throw "BackupPath is required for Verify action"
                }
            }
            'Report' {
                if (-not $ReportPath) {
                    throw "ReportPath is required for Report action"
                }
            }
            'Restore' {
                if (-not $BackupDirectory) {
                    throw "BackupDirectory is required for Restore action"
                }
                if (-not $RestoreDirectory) {
                    throw "RestoreDirectory is required for Restore action"
                }
            }
            'Cleanup' {
                if (-not $BackupName) {
                    throw "BackupName is required for Cleanup action"
                }
            }
        }
        
        $scriptRoot = $PSScriptRoot

        # Dynamically load all module scripts from the Modules directory
        $modulesDir = Join-Path $scriptRoot 'Modules'
        if (Test-Path $modulesDir) {
            Get-ChildItem -Path $modulesDir -Recurse -Filter '*.ps1' -File | Sort-Object -Property FullName | ForEach-Object {
                try {
                    . $_.FullName
                }
                catch {
                    Write-Verbose "Failed to load module script: $($_.FullName) - $($_.Exception.Message)"
                }
            }
        }
        
        # Suppress output if Quiet mode
        if ($Quiet) {
            $VerbosePreference = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
        }
        
        # Load config for DefaultBackupType if BackupType not explicitly provided
        if ($Action -eq 'Backup' -and -not $PSBoundParameters.ContainsKey('BackupType')) {
            $configFilePath = if ($ConfigPath) { $ConfigPath } else { Join-Path $scriptRoot "..\config\backup-config.json" }
            if (Test-Path $configFilePath) {
                try {
                    $config = Get-Content $configFilePath -Raw | ConvertFrom-Json
                    if ($config.GlobalSettings.DefaultBackupType) {
                        $BackupType = $config.GlobalSettings.DefaultBackupType
                        Write-Verbose "Using DefaultBackupType from config: $BackupType"
                    }
                }
                catch {
                    Write-Verbose "Could not load DefaultBackupType from config: $_"
                }
            }
        }
        
        Write-Log -Message "=== FileGuardian Started ===" -Level Info
        Write-Log -Message "Action: $Action" -Level Info
    }
    
    process {
        try {
            switch ($Action) {
                'Backup' {
                    Write-Log -Message "Starting backup operation..." -Level Info
                    
                    switch ($BackupType) {
                        'Full' {
                            Write-Log -Message "Starting FULL backup..." -Level Info
                            Write-Log -Message "Source: $SourcePath" -Level Info
                            
                            # Build parameters for backup function
                            $backupParams = @{
                                SourcePath = $SourcePath
                            }
                            
                            if ($DestinationPath) { $backupParams.DestinationPath = $DestinationPath }
                            if ($BackupName) { $backupParams.BackupName = $BackupName }
                            if ($ConfigPath) { $backupParams.ConfigPath = $ConfigPath }
                            if ($Compress) { $backupParams.Compress = $true }
                            if ($ExcludePatterns) { $backupParams.ExcludePatterns = $ExcludePatterns }
                            if ($ReportFormat) { $backupParams.ReportFormat = $ReportFormat }
                            if ($ReportOutputPath) { $backupParams.ReportPath = $ReportOutputPath }
                            
                            # Execute backup
                            $result = Invoke-FullBackup @backupParams
                        }
                        'Incremental' {
                            Write-Log -Message "Starting INCREMENTAL backup..." -Level Info
                            Write-Log -Message "Source: $SourcePath" -Level Info
                            
                            # Build parameters
                            $backupParams = @{
                                SourcePath = $SourcePath
                            }
                            
                            if ($DestinationPath) { $backupParams.DestinationPath = $DestinationPath }
                            if ($BackupName) { $backupParams.BackupName = $BackupName }
                            if ($ConfigPath) { $backupParams.ConfigPath = $ConfigPath }
                            if ($Compress) { $backupParams.Compress = $true }
                            if ($ExcludePatterns) { $backupParams.ExcludePatterns = $ExcludePatterns }
                            if ($ReportFormat) { $backupParams.ReportFormat = $ReportFormat }
                            if ($ReportOutputPath) { $backupParams.ReportPath = $ReportOutputPath }
                            
                            $result = Invoke-IncrementalBackup @backupParams
                        }
                    }
                    
                    # Handle post-backup actions
                    if ($result) {
                        Write-Log -Message "Backup completed successfully" -Level Success
                        Write-Log -Message "Files backed up: $($result.FilesBackedUp)" -Level Info
                        Write-Log -Message "Total size: $($result.TotalSizeMB) MB" -Level Info
                        
                        if ($result.ReportSigned) {
                            Write-Log -Message "Report signature: $($result.ReportSignature)" -Level Info
                        }
                        
                        return $result
                    }
                }
                
                'Verify' {
                    Write-Log -Message "Starting integrity verification..." -Level Info
                    Write-Log -Message "Backup path: $BackupPath" -Level Info
                    
                    $verifyParams = @{
                        BackupPath = $BackupPath
                    }
                    
                    $result = Test-BackupIntegrity @verifyParams
                    
                    if ($result) {
                        if ($result.IsIntact) {
                            Write-Log -Message "Backup integrity verified successfully" -Level Success
                            Write-Log -Message "All files verified: $($result.Summary.VerifiedCount) files" -Level Info
                        } else {
                            Write-Log -Message "Backup integrity verification FAILED" -Level Error
                            $issueCount = $result.Summary.CorruptedCount + $result.Summary.MissingCount
                            Write-Log -Message "Issues found: $issueCount (Corrupted: $($result.Summary.CorruptedCount), Missing: $($result.Summary.MissingCount))" -Level Error
                        }
                        
                        return $result
                    }
                }
                
                'Report' {
                    Write-Log -Message "Verifying report signature..." -Level Info
                    Write-Log -Message "Report path: $ReportPath" -Level Info
                    
                    $result = Confirm-ReportSignature -ReportPath $ReportPath
                    
                    if ($result.IsValid) {
                        Write-Log -Message "Report signature is VALID" -Level Success
                    } else {
                        Write-Log -Message "Report signature is INVALID or MISSING" -Level Error
                    }
                    
                    return $result
                }
                
                'Restore' {
                    Write-Log -Message "Starting restore operation..." -Level Info
                    Write-Log -Message "BackupDirectory: $BackupDirectory" -Level Info
                    Write-Log -Message "RestoreDirectory: $RestoreDirectory" -Level Info

                    # Discover and normalize backups
                    $resolved = Resolve-Backups -BackupDirectory $BackupDirectory
                    if (-not $resolved -or $resolved.Count -eq 0) {
                        throw "No backups found in BackupDirectory: $BackupDirectory"
                    }

                    # Find the most recent Full backup
                    $fulls = $resolved | Where-Object { $_.Metadata.BackupType -and ($_.Metadata.BackupType -match 'Full') } | Sort-Object -Property Timestamp -Descending
                    if (-not $fulls -or $fulls.Count -eq 0) {
                        throw "No Full backup found in BackupDirectory: $BackupDirectory"
                    }

                    $latestFull = $fulls | Select-Object -First 1

                    # Select incrementals occurring after the full
                    $incrementals = $resolved |
                        Where-Object { $_.Metadata.BackupType -and ($_.Metadata.BackupType -match 'Incremental') -and $_.Timestamp -gt $latestFull.Timestamp } |
                        Sort-Object -Property Timestamp

                    # Build restore chain: full then incrementals
                    $chain = @()
                    $chain += $latestFull
                    if ($incrementals) { $chain += $incrementals }

                    # Perform restore
                    $success = Invoke-Restore -Chain $chain -RestoreDirectory $RestoreDirectory
                    if ($success) {
                        Write-Log -Message "Restore completed successfully" -Level Success
                        $result = [PSCustomObject]@{
                            RestoredFull = $latestFull.Path
                            IncrementalsApplied = ($incrementals | Measure-Object).Count
                            RestoredTo = $RestoreDirectory
                        }
                        return $result
                    }
                }
                
                'Schedule' {
                    Write-Log -Message "Managing scheduled tasks..." -Level Info
                    
                    $scheduleParams = @{}
                    
                    if ($ConfigPath) { $scheduleParams.ConfigPath = $ConfigPath }
                    if ($BackupName) { $scheduleParams.BackupName = $BackupName }
                    if ($Remove) { $scheduleParams.Remove = $true }
                    
                    Register-BackupSchedule @scheduleParams
                }
                
                'Cleanup' {
                    Write-Log -Message "Starting retention cleanup..." -Level Info
                    
                    # Load config to get backup settings
                    $configFilePath = if ($ConfigPath) { $ConfigPath } else { Join-Path $scriptRoot "..\config\backup-config.json" }
                    
                    if (-not (Test-Path $configFilePath)) {
                        throw "Configuration file not found: $configFilePath"
                    }
                    
                    $config = Get-Content $configFilePath -Raw | ConvertFrom-Json
                    
                    if (-not $config.ScheduledBackups) {
                        throw "No scheduled backups found in configuration."
                    }
                    
                    # Find the backup configuration
                    $backupConfig = $config.ScheduledBackups | Where-Object { $_.Name -eq $BackupName }
                    if (-not $backupConfig) {
                        throw "Backup '$BackupName' not found in configuration."
                    }
                    
                    # Determine retention days
                    $days = if ($RetentionDays) {
                        $RetentionDays
                    } elseif ($backupConfig.RetentionDays) {
                        $backupConfig.RetentionDays
                    } elseif ($config.BackupSettings.RetentionDays) {
                        $config.BackupSettings.RetentionDays
                    } else {
                        throw "No RetentionDays configured for backup: $BackupName"
                    }
                    
                    # Determine backup directory
                    $backupDir = if ($CleanupBackupDirectory) {
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
                    
                    # Perform cleanup
                    $result = Invoke-BackupRetention -BackupDirectory $backupDir -RetentionDays $days -BackupName $BackupName
                    
                    if ($result.DeletedCount -gt 0) {
                        Write-Log -Message "Cleanup completed: Deleted $($result.DeletedCount) backup(s), freed $($result.FreedSpaceMB) MB" -Level Success
                    } else {
                        Write-Log -Message "Cleanup completed: No backups exceeded retention period" -Level Info
                    }
                    
                    return $result
                }
            }
        }
        catch {
            Write-Log -Message "ERROR: $($_.Exception.Message)" -Level Error
            throw
        }
    }
    
    end {
        Write-Log -Message "=== FileGuardian Finished ===" -Level Info
    }
}