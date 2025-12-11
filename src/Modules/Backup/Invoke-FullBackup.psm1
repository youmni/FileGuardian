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
    
    .EXAMPLE
        Invoke-FullBackup -SourcePath "C:\Data"
        Uses destination and settings from config file
    
    .EXAMPLE
        Invoke-FullBackup -SourcePath "C:\Data" -DestinationPath "D:\Backups"
        Override destination from config
    
    .EXAMPLE
        Invoke-FullBackup -Compress -BackupName "MyBackup"
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
        [string[]]$ExcludePatterns
    )
    
    begin {
        # Import Read-Config module
        $configModule = Join-Path $PSScriptRoot "..\..\Modules\Config\Read-Config.psm1"
        if (Test-Path $configModule) {
            Import-Module $configModule -Force
        }
        
        # Load configuration
        try {
            $config = if ($ConfigPath) {
                Read-Config -ConfigPath $ConfigPath
            } else {
                Read-Config -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Verbose "Could not load config file: $_. Using parameters only."
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
        
        Write-Verbose "Starting full backup..."
        Write-Verbose "Source: $SourcePath"
        Write-Verbose "Destination: $backupDestination"
    }
    
    process {
        try {
            # Create destination directory if it doesn't exist
            if (-not (Test-Path $DestinationPath)) {
                Write-Verbose "Creating destination directory: $DestinationPath"
                New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            }
            
            # Get all files from source
            Write-Verbose "Scanning source directory..."
            $files = Get-ChildItem -Path $SourcePath -Recurse -File
            
            # Apply exclusions
            if ($ExcludePatterns.Count -gt 0) {
                Write-Verbose "Applying exclusion patterns: $($ExcludePatterns -join ', ')"
                foreach ($pattern in $ExcludePatterns) {
                    $files = $files | Where-Object { $_.Name -notlike $pattern }
                }
            }
            
            $totalFiles = $files.Count
            $copiedFiles = 0
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            
            Write-Verbose "Found $totalFiles files to backup (Total size: $([Math]::Round($totalSize/1MB, 2)) MB)"
            
            # Copy files to temporary or final destination
            $tempDir = Join-Path $env:TEMP "FileGuardian_$timestamp"
            $finalDestination = if ($Compress) { $tempDir } else { $backupDestination }
            
            New-Item -Path $finalDestination -ItemType Directory -Force | Out-Null
            
            foreach ($file in $files) {
                $relativePath = $file.FullName.Substring($SourcePath.Length).TrimStart('\')
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
            
            Write-Verbose "Full backup completed successfully"
            return [PSCustomObject]$backupInfo
        }
        catch {
            Write-Error "Full backup failed: $_"
            throw
        }
    }
}