function Compress-Backup {
    <#
    .SYNOPSIS
        Compresses a backup directory into a ZIP archive.
    
    .DESCRIPTION
        Takes a source directory and creates a compressed ZIP archive.
        Optionally cleans up the source directory after compression.
    
    .PARAMETER SourcePath
        The source directory to compress.
    
    .PARAMETER DestinationPath
        The path where the ZIP file will be created (including .zip extension).
    
    .PARAMETER CompressionLevel
        Compression level: Optimal, Fastest, or NoCompression. Defaults to Optimal.
    
    .PARAMETER RemoveSource
        If specified, removes the source directory after successful compression.
    
    .EXAMPLE
        Compress-Backup -SourcePath "C:\Backups\TempBackup" -DestinationPath "C:\Backups\Backup.zip"
    
    .EXAMPLE
        Compress-Backup -SourcePath "C:\Backups\TempBackup" -DestinationPath "C:\Backups\Backup.zip" -RemoveSource
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [Parameter()]
        [ValidateSet('Optimal', 'Fastest', 'NoCompression')]
        [string]$CompressionLevel = 'Optimal',
        
        [Parameter()]
        [switch]$RemoveSource
    )
    
    $result = $null
    try {
        Write-Log -Message "Starting compression of backup..." -Level Info
        Write-Verbose "Source: $SourcePath"
        Write-Verbose "Destination: $DestinationPath"
        Write-Verbose "Compression Level: $CompressionLevel"

        # Ensure destination directory exists
        $destinationDir = Split-Path $DestinationPath -Parent
        if ($destinationDir -and -not (Test-Path $destinationDir)) {
            New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
        }

        # Get source size
        $sourceFiles = Get-ChildItem -Path $SourcePath -Recurse -File
        $sourceSize = ($sourceFiles | Measure-Object -Property Length -Sum).Sum
        $fileCount = $sourceFiles.Count

        Write-Log -Message "Compressing $fileCount files (Total: $([Math]::Round($sourceSize/1MB, 2)) MB)" -Level Info
        Write-Verbose "Compressing $fileCount files (Total: $([Math]::Round($sourceSize/1MB, 2)) MB)"

        # Remove existing destination if it exists
        if (Test-Path $DestinationPath) {
            Write-Verbose "Removing existing archive: $DestinationPath"
            Remove-Item -Path $DestinationPath -Force
        }

        # Create the archive
        Compress-Archive -Path "$SourcePath\*" -DestinationPath $DestinationPath -CompressionLevel $CompressionLevel -Force
        # Reset progress bar
        Write-Progress -Activity "Compress-Archive" -Completed

        # Get compressed size
        $compressedSize = (Get-Item $DestinationPath).Length
        if ($sourceSize -eq 0) { $compressionRatio = 0 } else { $compressionRatio = [Math]::Round((1 - ($compressedSize/$sourceSize)) * 100, 2) }

        Write-Log -Message "Compression completed: $([Math]::Round($compressedSize/1MB, 2)) MB (${compressionRatio}% reduction)" -Level Success
        Write-Verbose "Compression completed: $([Math]::Round($compressedSize/1MB, 2)) MB (${compressionRatio}% reduction)"

        $result = [PSCustomObject]@{
            SourcePath = $SourcePath
            DestinationPath = $DestinationPath
            OriginalSizeMB = [Math]::Round($sourceSize/1MB, 2)
            CompressedSizeMB = [Math]::Round($compressedSize/1MB, 2)
            CompressionRatio = $compressionRatio
            FileCount = $fileCount
            CompressionLevel = $CompressionLevel
            Success = $true
        }

        return $result
    }
    catch {
        Write-Error "Compression failed: $_"
        throw
    }
    finally {
        # Only remove the source when compression succeeded and RemoveSource was requested.
        if ($RemoveSource) {
            if ($result -and $result.Success) {
                if (Test-Path $SourcePath) {
                    try {
                        Remove-Item -Path $SourcePath -Recurse -Force -ErrorAction Stop
                    }
                    catch {
                        Write-Log -Message ("Failed to remove source directory after compression: {0}. {1}" -f $SourcePath, $_.Exception.Message) -Level Warning
                    }
                }
            }
            else {
                Write-Verbose "Compression did not complete successfully; not removing source directory: $SourcePath"
            }
        }
    }
}