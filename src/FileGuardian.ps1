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
        The action to perform: Backup, Verify, Restore, Report
    
    .PARAMETER SourcePath
        Source directory or file to backup (required for Backup action).
    
    .PARAMETER DestinationPath
        Destination directory for backups. If not specified, uses config file.
    
    .PARAMETER BackupType
        Type of backup: Full, Incremental, Differential. Default: Full
    
    .PARAMETER BackupPath
        Path to backup to verify (required for Verify action).
    
    .PARAMETER ReportPath
        Path to report file to verify signature (required for Report action).
    
    .PARAMETER BackupName
        Custom name for the backup. Defaults to auto-generated timestamp.
    
    .PARAMETER ConfigPath
        Path to configuration file. Defaults to config/backup-config.json
    
    .PARAMETER Compress
        Compress the backup into a ZIP archive.
    
    .PARAMETER ExcludePatterns
        Array of file patterns to exclude (e.g., "*.tmp", "*.log").
    
    .PARAMETER Quiet
        Suppress console output (logs still written).
    
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
    
    .NOTES
        This is the recommended way to use FileGuardian. All underlying modules
        are called automatically based on the specified action and parameters.
    #>
    [CmdletBinding(DefaultParameterSetName='Backup')]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet('Backup', 'Verify', 'Report')]
        [string]$Action,
        
        # Backup parameters
        [Parameter(ParameterSetName='Backup', Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,
        
        [Parameter(ParameterSetName='Backup')]
        [string]$DestinationPath,
        
        [Parameter(ParameterSetName='Backup')]
        [ValidateSet('Full', 'Incremental', 'Differential')]
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
        
        # Common parameters
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
        $modulesPath = Join-Path $scriptRoot "Modules"
            
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
                        'Differential' {
                            Write-Log -Message "Starting DIFFERENTIAL backup..." -Level Info
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
                            
                            $result = Invoke-DifferentialBackup @backupParams
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