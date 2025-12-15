function Invoke-FullBackup {
    <#
    .SYNOPSIS
        Performs a full backup of specified source directories.
    
    .DESCRIPTION
        Creates a complete backup of all files in the source directory to the 
        destination. All files are copied regardless of their modification status.
        Can load settings from configuration file or use explicit parameters.
    
    .PARAMETER SourcePath
        The source directory or file to backup. Required parameter.
    
    .PARAMETER DestinationPath
        The destination directory where the backup will be stored. If not specified, uses config file.
    
    .PARAMETER ConfigPath
        Path to the configuration file. Defaults to config/backup-config.json
    
    .PARAMETER BackupName
        Optional name for the backup. Defaults to "FullBackup_YYYYMMDD_HHMMSS"
    
    .PARAMETER Compress
        If specified, the backup will be compressed into a ZIP archive. If not specified, uses config file setting.
    
    .PARAMETER ExcludePatterns
        Array of file patterns to exclude from backup (e.g., "*.tmp", "*.log"). If not specified, uses config file.
    
    .PARAMETER ReportFormat
        Format for the backup report. Default is JSON. Supported: JSON, HTML (future).
    
    .EXAMPLE
        Invoke-FullBackup -SourcePath "C:\Data"
        Uses destination and settings from config file
    
    .EXAMPLE
        Invoke-FullBackup -SourcePath "C:\Data" -DestinationPath "D:\Backups"
        Override destination from config
    
    .EXAMPLE
        Invoke-FullBackup -Compress -BackupName "MyBackup" -ReportFormat "JSON"
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
        [string]$BackupName = "FullBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
        
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
        # Import helper modules
        $configHelperModule = Join-Path $PSScriptRoot "Initialize-BackupConfiguration.psm1"
        Import-Module $configHelperModule -Force
        
        # Load and initialize configuration
        $configResult = Initialize-BackupConfiguration -ConfigPath $ConfigPath -DestinationPath $DestinationPath -Compress $Compress -ExcludePatterns $ExcludePatterns -BoundParameters $PSBoundParameters
        
        $DestinationPath = $configResult.DestinationPath
        $Compress = $configResult.Compress
        $ExcludePatterns = $configResult.ExcludePatterns
        
        # Add timestamp to backup name if custom name was provided
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        if ($PSBoundParameters.ContainsKey('BackupName')) {
            $BackupName = "${BackupName}_$timestamp"
        }
        
        $backupDestination = Join-Path $DestinationPath $BackupName
        
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
        
        Write-Log -Message "Starting full backup from '$SourcePath' to '$backupDestination'" -Level Info
    }
    
    process {
        try {
            # Create destination directory if it doesn't exist
            if (-not (Test-Path $DestinationPath)) {
                Write-Log -Message "Creating destination directory: $DestinationPath" -Level Info
                Write-Verbose "Creating destination directory: $DestinationPath"
                New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            }
            
            # Get all files from source
            Write-Log -Message "Scanning source directory..." -Level Info
            $files = Get-ChildItem -Path $SourcePath -Recurse -File
            $originalFileCount = $files.Count
            
            # Apply exclusions
            if ($ExcludePatterns.Count -gt 0) {
                Write-Verbose "Applying exclusion patterns: $($ExcludePatterns -join ', ')"
                foreach ($pattern in $ExcludePatterns) {
                    $files = $files | Where-Object { $_.Name -notlike $pattern }
                }
                $excludedCount = $originalFileCount - $files.Count
                if ($excludedCount -gt 0) {
                    Write-Log -Message "Excluded $excludedCount files based on patterns" -Level Info
                }
            }
            
            $totalFiles = $files.Count
            $copiedFiles = 0
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            
            Write-Log -Message "Found $totalFiles files to backup (Total size: $([Math]::Round($totalSize/1MB, 2)) MB)" -Level Info
            
            # Copy files to temporary or final destination
            $tempDir = Join-Path $env:TEMP "FileGuardian_$timestamp"
            $finalDestination = if ($Compress) { $tempDir } else { $backupDestination }
            
            New-Item -Path $finalDestination -ItemType Directory -Force | Out-Null
            
            # Resolve source path to absolute
            $absoluteSourcePath = (Resolve-Path $SourcePath).Path
            
            foreach ($file in $files) {
                $relativePath = $file.FullName.Substring($absoluteSourcePath.Length).TrimStart('\')
                $targetPath = Join-Path $finalDestination $relativePath
                $targetDir = Split-Path $targetPath -Parent
                
                if (-not (Test-Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                }
                
                Copy-Item -Path $file.FullName -Destination $targetPath -Force
                $copiedFiles++
                
                if ($copiedFiles % 100 -eq 0) {
                    Write-Verbose "Progress: $copiedFiles / $totalFiles files copied"
                }
            }
            
            Write-Log -Message "Full backup completed successfully - $copiedFiles files copied" -Level Success
            
            # Save backup metadata for integrity verification BEFORE compression
            $metadataHelperModule = Join-Path $PSScriptRoot "Save-BackupMetadata.psm1"
            Import-Module $metadataHelperModule -Force
            
            $metadataTargetPath = if ($Compress) { Join-Path $tempDir ".backup-metadata.json" } else { Join-Path $backupDestination ".backup-metadata.json" }
            Save-BackupMetadata -BackupType "Full" -SourcePath $SourcePath -Timestamp $timestamp -FilesBackedUp $copiedFiles -TargetPath $metadataTargetPath
            
            # Handle compression or return direct copy info
            if ($Compress) {
                $zipPath = "$backupDestination.zip"
                Write-Verbose "Using Compress-Backup module for compression..."
                
                try {
                    $compressionResult = Compress-Backup -SourcePath $tempDir -DestinationPath $zipPath -CompressionLevel Optimal -RemoveSource -Verbose:$VerbosePreference
                    
                    $backupInfo = @{
                        Type = "Full"
                        BackupName = $BackupName
                        SourcePath = $SourcePath
                        DestinationPath = $zipPath
                        Timestamp = $timestamp
                        FilesBackedUp = $copiedFiles
                        TotalSizeMB = $compressionResult.OriginalSizeMB
                        CompressedSizeMB = $compressionResult.CompressedSizeMB
                        CompressionRatio = $compressionResult.CompressionRatio
                        Compressed = $true
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
                    Type = "Full"
                    BackupName = $BackupName
                    SourcePath = $SourcePath
                    DestinationPath = $backupDestination
                    Timestamp = $timestamp
                    FilesBackedUp = $copiedFiles
                    TotalSizeMB = [Math]::Round($totalSize/1MB, 2)
                    Compressed = $false
                }
            }
            
            # Always save integrity state
            $integrityHelperModule = Join-Path $PSScriptRoot "Invoke-IntegrityStateSave.psm1"
            Import-Module $integrityHelperModule -Force
            
            $backupInfo['IntegrityStateSaved'] = Invoke-IntegrityStateSave -SourcePath $SourcePath -DestinationPath $DestinationPath -BackupName $backupInfo.DestinationPath -Compress $Compress
            
            # Verify previous backups integrity
            $previousBackupsHelperModule = Join-Path $PSScriptRoot "Test-PreviousBackups.psm1"
            Import-Module $previousBackupsHelperModule -Force
            
            $verificationResult = Test-PreviousBackups -BackupDestination $backupInfo.DestinationPath -SourcePath $SourcePath -Compress $Compress
            $backupInfo['PreviousBackupsVerified'] = $verificationResult.VerifiedCount
            $backupInfo['CorruptedBackups'] = $verificationResult.CorruptedBackups
            $backupInfo['VerifiedBackupsOK'] = $verificationResult.VerifiedBackupsOK
            
            # Generate report (ALWAYS - this is mandatory)
            $reportHelperModule = Join-Path $PSScriptRoot "New-BackupReport.psm1"
            Import-Module $reportHelperModule -Force
            
            $backupInfo = New-BackupReport -BackupInfo $backupInfo -ReportFormat $ReportFormat -ReportPath $ReportPath
            
            return [PSCustomObject]$backupInfo
        }
        catch {
            Write-Error "Full backup failed: $_"
            throw
        }
    }
}