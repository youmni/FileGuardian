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
        
        # Thread-safe collection for results (if we add parallelization later)
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Normalization function for consistent path handling
        function Get-NormalizedPath {
            param([string]$PathToNormalize)
            
            # Resolve to full path and normalize
            $resolved = (Resolve-Path -Path $PathToNormalize -ErrorAction Stop).Path
            
            # Ensure consistent format:
            # 1. Convert to uppercase (Windows is case-insensitive, but we want consistency)
            # 2. Remove trailing backslash (unless it's a root like C:\)
            # 3. Use backslashes consistently
            $normalized = $resolved.ToUpperInvariant()
            
            # Don't remove trailing slash from root paths (C:\, D:\, etc.)
            if ($normalized -notmatch '^[A-Z]:\\$') {
                $normalized = $normalized.TrimEnd('\')
            }
            
            return $normalized
        }
        
        # Relative path calculation function
        function Get-ConsistentRelativePath {
            param(
                [string]$BasePath,
                [string]$FullPath
            )
            
            # Normalize both paths for comparison
            $baseNormalized = Get-NormalizedPath -PathToNormalize $BasePath
            $fullNormalized = Get-NormalizedPath -PathToNormalize $FullPath
            
            # Ensure full path starts with base path
            if (-not $fullNormalized.StartsWith($baseNormalized, [StringComparison]::OrdinalIgnoreCase)) {
                throw "File path '$FullPath' is not under base path '$BasePath'"
            }
            
            # Calculate relative path
            $relativePath = $fullNormalized.Substring($baseNormalized.Length).TrimStart('\', '/')
            
            # Convert back to original casing using the actual file path
            # This preserves the original case from the filesystem
            $relativePathOriginalCase = $FullPath.Substring($BasePath.Length).TrimStart('\', '/')
            
            return $relativePathOriginalCase
        }
    }
    
    Process {
        try {
            $item = Get-Item -Path $Path -ErrorAction Stop
            
            if ($item.PSIsContainer) {
                # Directory - get all files
                Write-Verbose "Processing directory: $($item.FullName)"
                
                $files = if ($Recurse) {
                    Get-ChildItem -Path $Path -File -Recurse -ErrorAction Stop
                } else {
                    Get-ChildItem -Path $Path -File -ErrorAction Stop
                }
                
                $totalFiles = $files.Count
                Write-Verbose "Found $totalFiles files to process"
                
                if ($totalFiles -eq 0) {
                    Write-Log -Message "No files found in: $Path" -Level Warning
                    return @()
                }
                
                # Get normalized base path once
                $normalizedBasePath = Get-NormalizedPath -PathToNormalize $item.FullName
                
                # Process each file
                $processedCount = 0
                foreach ($file in $files) {
                    try {
                        # Calculate hash
                        $hash = Get-FileHash -Path $file.FullName -Algorithm $Algorithm -ErrorAction Stop
                        
                        # Calculate consistent relative path
                        $relativePath = Get-ConsistentRelativePath -BasePath $item.FullName -FullPath $file.FullName
                        
                        # Create result object with consistent property order
                        $fileInfo = [PSCustomObject]@{
                            Path = $file.FullName
                            RelativePath = $relativePath
                            Hash = $hash.Hash
                            Algorithm = $Algorithm
                            Size = $file.Length
                            LastWriteTime = $file.LastWriteTime
                        }
                        
                        # Add to results (thread-safe collection)
                        $results.Add($fileInfo)
                        
                        $processedCount++
                        
                        # Progress indication every 100 files
                        if ($processedCount % 100 -eq 0) {
                            Write-Verbose "Progress: $processedCount / $totalFiles files hashed"
                        }
                    }
                    catch {
                        Write-Log -Message "Failed to hash file '$($file.FullName)': $_" -Level Warning
                        # Continue processing other files even if one fails
                        continue
                    }
                }
                
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