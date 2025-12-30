function Get-FileIntegrityHash {
    <#
    .SYNOPSIS
        Calculates hash for a file or all files in a directory with parallel processing and caching.
    
    .DESCRIPTION
        Generates SHA256 hashes for files to track integrity with significant performance improvements:
        - Parallel processing using runspaces for concurrent hash calculations
        - Smart caching that reuses hashes for unchanged files (based on LastWriteTime and Size)
        - Thread-safe operations to prevent race conditions
        
        IMPORTANT: This function guarantees consistent relative path calculation
        across multiple runs to prevent phantom "file added/removed" issues.
    
    .PARAMETER Path
        Path to file or directory to hash.
    
    .PARAMETER Algorithm
        Hash algorithm to use. Default is SHA256.
    
    .PARAMETER Recurse
        Process directories recursively.
    
    .PARAMETER StateDirectory
        Optional. Directory containing state files (latest.json) for caching.
        If provided, the function will automatically load and use cached hashes.
    
    .PARAMETER MaxParallelJobs
        Maximum number of parallel hash calculations. Default is number of CPU cores.
    
    .EXAMPLE
        Get-FileIntegrityHash -Path "C:\Data"
        Get hashes for all files in C:\Data
    
    .EXAMPLE
        Get-FileIntegrityHash -Path "C:\Data" -Recurse -StateDirectory "C:\Backups\states"
        Get hashes with automatic caching from latest.json in state directory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter()]
        [ValidateSet('SHA256', 'SHA1', 'MD5')]
        [string]$Algorithm = 'SHA256',
        
        [Parameter()]
        [switch]$Recurse,
        
        [Parameter()]
        [string]$StateDirectory,
        
        [Parameter()]
        [int]$MaxParallelJobs = [Environment]::ProcessorCount
    )
    
    Begin {
        Write-Log -Message "Starting optimized hash calculation for: $Path (Algorithm: $Algorithm, MaxJobs: $MaxParallelJobs)" -Level Info
        $results = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()
        
        # Build cache lookup from state directory (thread-safe dictionary)
        $cache = [System.Collections.Concurrent.ConcurrentDictionary[string, PSCustomObject]]::new()
        
        # Auto-load previous state if StateDirectory is provided
        $previousState = $null
        if ($StateDirectory -and (Test-Path $StateDirectory)) {
            $latestStateFile = Join-Path $StateDirectory "latest.json"
            if (Test-Path $latestStateFile) {
                try {
                    $previousState = Get-Content -Path $latestStateFile -Raw | ConvertFrom-Json
                    Write-Verbose "Loaded previous state from: $latestStateFile"
                }
                catch {
                    Write-Warning "Failed to load previous state: $_"
                }
            }
        }
        
        if ($previousState -and $previousState.Files) {
            foreach ($file in $previousState.Files) {
                $cacheKey = "$($file.RelativePath)|$($file.Size)|$($file.LastWriteTime)"
                $null = $cache.TryAdd($cacheKey, $file)
            }
            Write-Verbose "Loaded $($cache.Count) cached entries from previous state"
        }
    }
    
    Process {
        try {
            $item = Get-Item -Path $Path -ErrorAction Stop
            
            if ($item.PSIsContainer) {
                # Directory - get all files
                Write-Verbose "Processing directory: $($item.FullName)"
                
                $childParams = @{ Path = $Path; File = $true; ErrorAction = 'Stop' }
                if ($Recurse) { $childParams['Recurse'] = $true }

                # Collect all files first
                $allFiles = @(Get-ChildItem @childParams)
                $totalFiles = $allFiles.Count
                
                Write-Verbose "Found $totalFiles files to process"
                Write-Log -Message "Calculating $Algorithm hashes for $totalFiles files in $Path" -Level Info
                
                if ($totalFiles -eq 0) {
                    Write-Log -Message "No files found in: $Path" -Level Warning
                    return @()
                }

                # Create runspace pool for parallel processing
                $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxParallelJobs)
                $runspacePool.Open()
                
                # Script block for parallel hash calculation
                $scriptBlock = {
                    param($FilePath, $FileSize, $FileLastWrite, $BaseDir, $Algorithm, $CacheDict)
                    
                    try {
                        # Calculate relative path
                        $baseNormalized = $BaseDir.ToUpperInvariant().TrimEnd('\')
                        $fileNormalized = $FilePath.ToUpperInvariant()
                        
                        if (-not $fileNormalized.StartsWith($baseNormalized, [StringComparison]::OrdinalIgnoreCase)) {
                            throw "File path '$FilePath' is not under base path '$BaseDir'"
                        }
                        
                        $relativePath = $FilePath.Substring($BaseDir.Length).TrimStart('\', '/')
                        
                        # Check cache
                        $cacheKey = "$relativePath|$FileSize|$FileLastWrite"
                        $cached = $null
                        
                        if ($CacheDict.TryGetValue($cacheKey, [ref]$cached)) {
                            # Cache hit - reuse hash
                            return [PSCustomObject]@{
                                Path          = $FilePath
                                RelativePath  = $relativePath
                                Hash          = $cached.Hash
                                Algorithm     = $Algorithm
                                Size          = $FileSize
                                LastWriteTime = $FileLastWrite
                                CacheHit      = $true
                            }
                        }
                        
                        # Cache miss - calculate hash
                        $hash = Get-FileHash -Path $FilePath -Algorithm $Algorithm -ErrorAction Stop
                        
                        return [PSCustomObject]@{
                            Path          = $FilePath
                            RelativePath  = $relativePath
                            Hash          = $hash.Hash
                            Algorithm     = $Algorithm
                            Size          = [long]$FileSize
                            LastWriteTime = $FileLastWrite
                        }
                    }
                    catch {
                        Write-Warning "Failed to hash file '$FilePath': $_"
                        return $null
                    }
                }
                
                # Create jobs for each file
                $jobs = [System.Collections.ArrayList]::new()
                
                foreach ($file in $allFiles) {
                    $powershell = [powershell]::Create().AddScript($scriptBlock).AddArgument($file.FullName).AddArgument($file.Length).AddArgument($file.LastWriteTime).AddArgument($item.FullName).AddArgument($Algorithm).AddArgument($cache)
                    $powershell.RunspacePool = $runspacePool
                    
                    $null = $jobs.Add([PSCustomObject]@{
                        PowerShell = $powershell
                        Handle     = $powershell.BeginInvoke()
                        File       = $file.Name
                    })
                }
                
                # Collect results with progress reporting
                $completed = 0
                $cacheHits = 0
                $cacheMisses = 0
                
                Write-Progress -Activity "Hashing files" -Status "Processing..." -PercentComplete 0
                
                while ($jobs.Count -gt 0) {
                    # Check for completed jobs
                    for ($i = $jobs.Count - 1; $i -ge 0; $i--) {
                        $job = $jobs[$i]
                        
                        if ($job.Handle.IsCompleted) {
                            try {
                                $resultCollection = $job.PowerShell.EndInvoke($job.Handle)

                                if ($resultCollection) {
                                    foreach ($res in $resultCollection) {
                                        if ($null -eq $res) { continue }

                                        $cacheKey = "$($res.RelativePath)|$($res.Size)|$($res.LastWriteTime)"
                                        if ($cache.ContainsKey($cacheKey)) {
                                            $cacheHits++
                                        } else {
                                            $cacheMisses++
                                        }

                                        $null = $results.Add($res)
                                    }
                                }
                                
                                $completed++
                                
                                if ($completed % 50 -eq 0 -or $completed -eq $totalFiles) {
                                    $percent = [math]::Round(($completed / $totalFiles) * 100, 0)
                                    $status = "Processed $completed of $totalFiles (Cache: $cacheHits hits, $cacheMisses misses)"
                                    Write-Progress -Activity "Hashing files" -Status $status -PercentComplete $percent
                                    Write-Verbose $status
                                }
                            }
                            catch {
                                Write-Warning "Job failed for file '$($job.File)': $_"
                            }
                            finally {
                                $job.PowerShell.Dispose()
                                $jobs.RemoveAt($i)
                            }
                        }
                    }
                    
                    # Small sleep to prevent CPU spinning
                    Start-Sleep -Milliseconds 50
                }
                
                Write-Progress -Activity "Hashing files" -Completed
                
                # Cleanup runspace pool
                $runspacePool.Close()
                $runspacePool.Dispose()
                
                Write-Log -Message "Hashed $completed files successfully (Cache hits: $cacheHits, misses: $cacheMisses)" -Level Info
                
                # Convert to array and sort by RelativePath for consistency
                $resultArray = $results.ToArray() | Sort-Object -Property RelativePath
                
                return $resultArray
            }
            else {
                # Single file - no parallelization needed
                Write-Verbose "Processing single file: $($item.FullName)"
                
                $relativePath = $item.Name
                
                # Check cache for single file
                $cacheKey = "$relativePath|$($item.Length)|$($item.LastWriteTime)"
                $cached = $null
                
                if ($cache.TryGetValue($cacheKey, [ref]$cached)) {
                    Write-Verbose "Cache hit for single file"
                    
                    $fileInfo = [PSCustomObject]@{
                        Path          = $item.FullName
                        RelativePath  = $relativePath
                        Hash          = $cached.Hash
                        Algorithm     = $Algorithm
                        Size          = [long]$item.Length
                        LastWriteTime = $item.LastWriteTime
                    }
                    
                    Write-Log -Message "Hashed single file successfully (cache hit)" -Level Info
                    return $fileInfo
                }
                
                # Calculate hash
                try {
                    $hash = Get-FileHash -Path $item.FullName -Algorithm $Algorithm -ErrorAction Stop
                    
                    $fileInfo = [PSCustomObject]@{
                        Path          = $item.FullName
                        RelativePath  = $relativePath
                        Hash          = $hash.Hash
                        Algorithm     = $Algorithm
                        Size          = [long]$item.Length
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