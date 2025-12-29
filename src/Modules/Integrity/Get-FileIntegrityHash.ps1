function Get-FileIntegrityHash {
    <#
    .SYNOPSIS
        Calculates hash for a file or all files in a directory.
    
    .DESCRIPTION
        Generates SHA256 hashes for files to track integrity.
        Can process single files or entire directory trees.
        
        IMPORTANT: This function guarantees consistent relative path calculation
        across multiple runs to prevent phantom "file added/removed" issues.
    
    .PARAMETER Path
        Path to file or directory to hash.
    
    .PARAMETER Algorithm
        Hash algorithm to use. Default is SHA256.
    
    .PARAMETER Recurse
        Process directories recursively.
    
    .EXAMPLE
        Get-FileIntegrityHash -Path "C:\Data"
        Get hashes for all files in C:\Data
    
    .EXAMPLE
        Get-FileIntegrityHash -Path "C:\Data" -Recurse
        Get hashes for all files in C:\Data and subdirectories
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter()]
        [ValidateSet('SHA256', 'SHA1', 'MD5')]
        [string]$Algorithm = 'SHA256',
        
        [Parameter()]
        [switch]$Recurse
    )
    
    Begin {
        Write-Log -Message "Starting hash calculation for: $Path (Algorithm: $Algorithm)" -Level Info
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }
    
    Process {
        try {
            $item = Get-Item -Path $Path -ErrorAction Stop
            
            if ($item.PSIsContainer) {
                # Directory - get all files
                Write-Verbose "Processing directory: $($item.FullName)"
                
                # Stream files instead of loading all into memory
                $childParams = @{ Path = $Path; File = $true; ErrorAction = 'Stop' }
                if ($Recurse) { $childParams['Recurse'] = $true }

                # Count files with a streamed enumeration (does not keep objects in memory)
                $totalFiles = (Get-ChildItem @childParams | Measure-Object).Count
                Write-Verbose "Found $totalFiles files to process"
                Write-Log -Message "Calculating $Algorithm hashes for $totalFiles files in $Path" -Level Info
                Write-Progress -Activity "Hashing files" -Status "Starting..." -PercentComplete 0

                if ($totalFiles -eq 0) {
                    Write-Log -Message "No files found in: $Path" -Level Warning
                    return @()
                }

                # Process files as a stream to avoid high memory usage
                $processedCount = 0
                Get-ChildItem @childParams | ForEach-Object {
                    $file = $_
                    try {
                        $hash = Get-FileHash -Path $file.FullName -Algorithm $Algorithm -ErrorAction Stop

                        $relativePath = Get-ConsistentRelativePath -BasePath $item.FullName -FullPath $file.FullName

                        $fileInfo = [PSCustomObject]@{
                            Path = $file.FullName
                            RelativePath = $relativePath
                            Hash = $hash.Hash
                            Algorithm = $Algorithm
                            Size = $file.Length
                            LastWriteTime = $file.LastWriteTime
                        }

                        $results.Add($fileInfo)

                        $processedCount++

                        if ($processedCount % 100 -eq 0) {
                            if ($totalFiles -gt 0) {
                                $percent = [math]::Round(($processedCount / $totalFiles) * 100, 0)
                                Write-Verbose "Progress: $processedCount / $totalFiles files hashed"
                                Write-Progress -Activity "Hashing files" -Status "Hashed $processedCount of $totalFiles" -PercentComplete $percent
                            }
                            else {
                                Write-Progress -Activity "Hashing files" -Status "Hashed $processedCount files"
                            }
                        }
                    }
                    catch {
                        Write-Log -Message "Failed to hash file '$($file.FullName)': $_" -Level Warning
                        continue
                    }
                }
                
                Write-Progress -Activity "Hashing files" -Completed
                Write-Log -Message "Hashed $processedCount files successfully" -Level Info
                
                # Return results as array (sorted by RelativePath for consistency)
                return $results | Sort-Object -Property RelativePath
            }
            else {
                # Single file
                Write-Verbose "Processing single file: $($item.FullName)"
                
                try {
                    $hash = Get-FileHash -Path $item.FullName -Algorithm $Algorithm -ErrorAction Stop
                    
                    # For single file, relative path is just the filename
                    $relativePath = $item.Name
                    
                    $fileInfo = [PSCustomObject]@{
                        Path = $item.FullName
                        RelativePath = $relativePath
                        Hash = $hash.Hash
                        Algorithm = $Algorithm
                        Size = $item.Length
                        LastWriteTime = $item.LastWriteTime
                    }
                    
                    Write-Progress -Activity "Hashing files" -Completed
                    Write-Log -Message "Hashed single file successfully" -Level Info
                    
                    return $fileInfo
                }
                catch {
                    Write-Log -Message "Failed to hash file '$($item.FullName)': $_" -Level Error
                    throw
                }
            }
        }
        catch {
            Write-Error "Failed to calculate hash: $_"
            throw
        }
    }
    
    End {
        Write-Log -Message "Completed hash calculation for: $Path" -Level Info
    }
}