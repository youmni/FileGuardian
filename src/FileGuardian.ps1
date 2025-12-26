# Ensure nested helper modules are loaded into this module's scope so
# internal calls (e.g., Invoke-FullBackup) are available to Invoke-FileGuardian.
# This keeps those helpers internal while allowing only `Invoke-FileGuardian`
# to be exported from the manifest.
try {
    $moduleDir = $PSScriptRoot
    $modulesPath = Join-Path $moduleDir 'Modules'
    if (Test-Path $modulesPath) {
        Get-ChildItem -Path $modulesPath -Recurse -Filter '*.psm1' -File | ForEach-Object {
            try {
                Import-Module -Name $_.FullName -Force -ErrorAction Stop
            }
            catch {
                Write-Verbose "Failed to import nested module '$($_.FullName)': $_"
            }
        }
    }
}
catch {
    Write-Verbose "Error while loading nested modules: $_"
}

function Invoke-FileGuardian {
    <#
    .SYNOPSIS
        Unified command for FileGuardian backup operations.
    
    .DESCRIPTION
        Main entry point for FileGuardian functionality. Supports backup operations,
        integrity verification, and reporting through a single command interface.
        
        This command orchestrates all FileGuardian modules and provides a simplified
        user experience compared to calling individual module functions.
    
    .PARAMETER Action
        The operation to perform. Valid values: 'Backup', 'Verify', 'Report', 'Restore'.
        - 'Backup': create a backup of `SourcePath` to the configured destination.
        - 'Verify': check integrity of a specific `BackupPath`.
        - 'Report': validate the digital signature of a report at `ReportPath`.
        - 'Restore': restore files from backups found in `BackupDirectory` to `RestoreDirectory`.

    .PARAMETER SourcePath
        Path to the source directory or file to include in a backup (required for
        `Action = 'Backup'`). Accepts absolute or relative paths. The path must exist.

    .PARAMETER DestinationPath
        Optional destination directory where backups will be stored. If omitted the
        destination defined in the configuration (`ConfigPath` or default config)
        will be used.

    .PARAMETER BackupType
        Backup mode to run: 'Full' or 'Incremental'. Default is 'Full'. Use 'Incremental'
        only when a valid previous full backup is available in the destination.

    .PARAMETER BackupPath
        Exact path to a single backup snapshot (used with `Action = 'Verify'`).
        Provide the path to the backup folder you want integrity-checked.

    .PARAMETER BackupDirectory
        Path to the folder that contains one or more FileGuardian backup folders
        (required for `Action = 'Restore'`). Can be a backups root (containing
        multiple dated backup folders) or a specific backup folder. When restoring,
        the code selects the most recent full backup in this directory and then
        applies any incremental backups with timestamps newer than that full.

    .PARAMETER RestoreDirectory
        Target directory where files will be restored (required for `Action = 'Restore'`).
        The directory will be created if it does not exist; ensure the running account
        has write permission. Existing files may be overwritten by the restore.

    .PARAMETER ReportPath
        Path to a generated report file whose digital signature should be validated
        (used with `Action = 'Report'`). The file must exist.

    .PARAMETER ReportOutputPath
        When performing a backup, the path (including filename) where the generated
        report will be written. This path does not need to exist beforehand.

    .PARAMETER BackupName
        Optional user-specified name for the backup. If omitted a timestamped name
        will be generated automatically.

    .PARAMETER ConfigPath
        Path to a JSON configuration file. If not provided the module will use
        'config/backup-config.json' relative to the script root.

    .PARAMETER Compress
        Switch to compress the backup into an archive (ZIP). Use `-Compress` to enable.

    .PARAMETER ExcludePatterns
        Array of wildcard patterns to exclude from the backup (for example
        @('*.tmp','node_modules\**')). Patterns use PowerShell wildcard semantics.

    .PARAMETER ReportFormat
        Output format for generated reports: 'JSON', 'HTML', or 'CSV'. If omitted
        the module default is used.

    .PARAMETER Quiet
        Suppress console informational and verbose output. Logging to files still occurs.
    
    .NOTES
        Reports are always generated and digitally signed for every backup.
    
    .EXAMPLE
        Invoke-FileGuardian -Action Backup -SourcePath "C:\Data"
        Performs full backup using config file settings
    
    .EXAMPLE
        Invoke-FileGuardian -Action Backup -SourcePath "C:\Data" -BackupType Incremental -Compress
        Performs compressed incremental backup
    
    .EXAMPLE
        Invoke-FileGuardian -Action Verify -BackupPath ".\backups\MyBackup_20251213_120000"
        Verifies integrity of specified backup
    
    .EXAMPLE
        Invoke-FileGuardian -Action Report -ReportPath ".\reports\backup_report.json"
        Verifies the digital signature of a backup report
    
    .EXAMPLE
        Invoke-FileGuardian -Action Backup -SourcePath "C:\Data" -DestinationPath "D:\Backups"
        Full backup (reports are always signed)
    
    .EXAMPLE
        Invoke-FileGuardian -Action Backup -SourcePath "C:\Data" -ReportFormat HTML
        Full backup with HTML report format

    .EXAMPLE
        Invoke-FileGuardian -Action Restore -BackupDirectory ".\backups\FileGuardian_20251225_164904" -RestoreDirectory "C:\RestoreTarget"
        Restores the most recent full backup plus applicable incremental backups to the specified target directory.

    .NOTES
        This is the recommended way to use FileGuardian. All underlying modules
        are called automatically based on the specified action and parameters.
    #>
    [CmdletBinding(DefaultParameterSetName='Backup')]
    param(
        [Parameter(Mandatory=$true, Position=0)]
            [ValidateSet('Backup', 'Verify', 'Report', 'Restore')]
            [string]$Action,
        
        # Backup parameters
        [Parameter(ParameterSetName='Backup', Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,

        # Restore parameters
        [Parameter(ParameterSetName='Restore', Mandatory=$true, Position=1)]
        [ValidateScript({ Test-Path $_ })]
        [string]$BackupDirectory,

        [Parameter(ParameterSetName='Restore', Mandatory=$true, Position=2)]
        [string]$RestoreDirectory,
        
        [Parameter(ParameterSetName='Backup')]
        [string]$DestinationPath,
        
        [Parameter(ParameterSetName='Backup')]
        [ValidateSet('Full', 'Incremental')]
        [string]$BackupType = 'Full',
        
        # Verify backup parameters
        [Parameter(ParameterSetName='Verify', Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$BackupPath,
        
        # Report path for verification (must exist)
        [Parameter(ParameterSetName='Report', Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ReportPath,
        
        # Report output path for backups (does not need to exist)
        [Parameter(ParameterSetName='Backup')]
        [string]$ReportOutputPath,
        
        [Parameter()]
        [string]$BackupName,
        
        [Parameter()]
        [string]$ConfigPath,
        
        [Parameter()]
        [switch]$Compress,
        
        [Parameter()]
        [string[]]$ExcludePatterns,
        
        [Parameter()]
        [ValidateSet('JSON', 'HTML', 'CSV')]
        [string]$ReportFormat,
        
        [Parameter()]
        [switch]$Quiet
    )
    
    begin {
        # Set up paths
        $scriptRoot = $PSScriptRoot
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
                    # Fall back to default
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
                        
                        # Report is already signed by backup modules
                        if ($result.ReportSigned) {
                            Write-Log -Message "Report signature: $($result.ReportSignature)" -Level Info
                        }
                        
                        return $result
                    }
                }
                
                'Verify' {
                    Write-Log -Message "Starting integrity verification..." -Level Info
                    Write-Log -Message "Backup path: $BackupPath" -Level Info
                    
                    # Execute verification
                    $verifyParams = @{
                        BackupPath = $BackupPath
                    }
                    
                    $result = Test-BackupIntegrity @verifyParams
                    
                    if ($result) {
                        # Check IsIntact property (the actual property name from Test-BackupIntegrity)
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
                    
                    # Execute verification - returns object with IsValid property
                    $result = Confirm-ReportSignature -ReportPath $ReportPath
                    
                    if ($result.IsValid) {
                        Write-Log -Message "Report signature is VALID" -Level Success
                    } else {
                        Write-Log -Message "Report signature is INVALID or MISSING" -Level Error
                    }
                    
                    # Return the result from Confirm-ReportSignature directly
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
            }
        }
        catch {
            Write-Log -Message "ERROR: $($_.Exception.Message)" -Level Error
            Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
            throw
        }
    }
    
    end {
        Write-Log -Message "=== FileGuardian Finished ===" -Level Info
    }
}