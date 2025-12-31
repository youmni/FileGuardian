function Invoke-FileGuardian {
    <#
    .SYNOPSIS
        Unified command for FileGuardian backup operations.

    .DESCRIPTION
        Main entry point for FileGuardian functionality. Supports backup operations,
        integrity verification, reporting, scheduling, restore and retention cleanup
        through a single command interface. Many parameters are optional and
        validated depending on the chosen `-Action`.

    .PARAMETER Action
        The operation to perform. Valid values: 'Backup', 'Verify', 'Report', 'Restore', 'Schedule' or 'Cleanup'.

    .PARAMETER SourcePath
        Path to the source directory to back up. Required when `-Action Backup` is used.

    .PARAMETER DestinationPath
        Optional destination root path where backups will be written. If omitted,
        the destination is taken from configuration or defaults.

    .PARAMETER BackupName
        Optional name for the backup configuration or backup job. Required by some
        operations (for example `-Action Cleanup` uses `-BackupName` to select configuration).

    .PARAMETER BackupType
        Type of backup to perform when `-Action Backup`. Valid values: 'Full', 'Incremental'.
        Default is 'Full' (can be overridden by configuration).

    .PARAMETER Compress
        Switch to enable compression of created backups (ZIP archives).

    .PARAMETER ExcludePatterns
        Array of file/directory patterns to exclude from backups (e.g. @('*.tmp','node_modules/**')).

    .PARAMETER ReportFormat
        Format for generated reports. Valid values: 'JSON', 'HTML', 'CSV'. If omitted,
        the configured default is used.

    .PARAMETER ReportOutputPath
        Output directory for generated backup reports. When provided, this path is
        forwarded to underlying report writers.

    .PARAMETER ReportPath
        Path to an existing report file to verify.

    .PARAMETER BackupPath
        Path to a backup to verify (used with `-Action Verify`). Can point to a
        backup directory or a compressed backup file.

    .PARAMETER BackupDirectory
        Directory containing backup files to restore from (used with `-Action Restore`).

    .PARAMETER RestoreDirectory
        Destination directory where backups will be restored (used with `-Action Restore`).

    .PARAMETER CleanupBackupDirectory
        Optional explicit backup directory used for `-Action Cleanup`. If omitted,
        the backup directory is taken from the named configuration or global settings.

    .PARAMETER ConfigPath
        Optional path to a custom configuration file (e.g. config\backup-config.json).

    .PARAMETER Remove
        Switch used by `-Action Schedule` to remove a scheduled task instead of registering it.

    .PARAMETER RetentionDays
        Integer number of days to retain backups (used with `-Action Cleanup`). If omitted,
        retention is read from the backup configuration.

    .PARAMETER Quiet
        Suppresses informational and verbose output when present.

    .EXAMPLE
        Invoke-FileGuardian -Action Backup -SourcePath "C:\Data" -DestinationPath "D:\Backups" -BackupName "MyBackup" -Compress -ReportFormat "HTML"

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
        
        [Parameter(Mandatory=$false)]
        [ValidateScript({ 
            if ($Action -eq 'Backup' -and -not (Test-Path $_)) {
                throw "Source path does not exist: $_"
            }
            $true
        })]
        [string]$SourcePath,

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
        
        [Parameter(Mandatory=$false)]
        [string]$CleanupBackupDirectory,
        
        [Parameter(Mandatory=$false)]
        [string]$DestinationPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Full', 'Incremental')]
        [string]$BackupType = 'Full',
        
        [Parameter(Mandatory=$false)]
        [ValidateScript({ 
            if ($Action -eq 'Verify' -and -not (Test-Path $_)) {
                throw "Backup path does not exist: $_"
            }
            $true
        })]
        [string]$BackupPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateScript({ 
            if ($Action -eq 'Report' -and -not (Test-Path $_)) {
                throw "Report path does not exist: $_"
            }
            $true
        })]
        [string]$ReportPath,
        
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
        
        [Parameter(Mandatory=$false)]
        [switch]$Remove,
        
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
        
        # Load config for DefaultBackupType using Read-Config
        if ($Action -eq 'Backup' -and -not $PSBoundParameters.ContainsKey('BackupType')) {
            try {
                if ($ConfigPath) {
                    $config = Read-Config -ConfigPath $ConfigPath
                }
                else {
                    $config = Read-Config
                }

                if ($config -and $config.GlobalSettings.DefaultBackupType) {
                    $BackupType = $config.GlobalSettings.DefaultBackupType
                    Write-Verbose "Using DefaultBackupType from config: $BackupType"
                }
            }
            catch {
                Write-Verbose "Could not load DefaultBackupType from config: $_"
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
                    $result = $null
                    
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
                    if (-not $PSBoundParameters.ContainsKey('BackupName') -or [string]::IsNullOrWhiteSpace($BackupName)) {
                        throw "BackupName is required for Cleanup action"
                    }

                    Write-Log -Message "Starting retention cleanup..." -Level Info

                    $cleanupParams = @{}
                    if ($ConfigPath) { $cleanupParams.ConfigPath = $ConfigPath }
                    if ($BackupName) { $cleanupParams.BackupName = $BackupName }
                    if ($CleanupBackupDirectory) { $cleanupParams.CleanupBackupDirectory = $CleanupBackupDirectory }
                    if ($RetentionDays) { $cleanupParams.RetentionDays = $RetentionDays }
                    if ($Quiet) { $cleanupParams.Quiet = $true }

                    $result = Invoke-BackupCleanup @cleanupParams

                    if ($result -and $result.DeletedCount -gt 0) {
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