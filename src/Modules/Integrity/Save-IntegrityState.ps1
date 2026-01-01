function Save-IntegrityState {
    <#
    .SYNOPSIS
        Saves current integrity state to JSON file.
    
    .DESCRIPTION
        Captures file hashes and saves them to states/latest.json.
        Rotates previous latest to prev.json.
        Also saves a backup-specific state file for future integrity verification.
    
    .PARAMETER SourcePath
        Path to backup source directory to track.
    
    .PARAMETER StateDirectory
        Directory where state files are stored. Default is .\states
    
    .PARAMETER BackupName
        Optional backup name to create a backup-specific state file
    
    .PARAMETER ExcludePatterns
        Array of file patterns to exclude from the integrity state (such as "*.tmp", "*.log", "node_modules/**")
        
    .EXAMPLE
        Save-IntegrityState -SourcePath "C:\Data"
        Saves integrity state for C:\Data

    .EXAMPLE
        Save-IntegrityState -SourcePath "C:\Data" -BackupName "MyBackup_20251214_120000"
        Saves both general and backup-specific integrity state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,

        [Parameter()]
        [string]$StateDirectory = ".\states",

        [Parameter()]
        [string]$BackupName,

        [Parameter()]
        [string[]]$ExcludePatterns
    )
    
    Begin {
        Write-Verbose "Saving integrity state for: $SourcePath"
        
        # Ensure state directory exists
        if (-not (Test-Path $StateDirectory)) {
            Write-Verbose "Creating state directory: $StateDirectory"
            New-Item -Path $StateDirectory -ItemType Directory -Force | Out-Null
        }
        
        $latestFile = Join-Path $StateDirectory "latest.json"
        $prevFile = Join-Path $StateDirectory "prev.json"
    }
    
    Process {
        try {

            # Get current hashes
            Write-Verbose "Calculating file hashes..."
            $rawHashes = @(Get-FileIntegrityHash -Path $SourcePath -Recurse -StateDirectory $StateDirectory)
            $rawHashes = $rawHashes | Where-Object { $_ -ne $null }

            if ($ExcludePatterns -and $ExcludePatterns.Count -gt 0) {
                $rawHashes = $rawHashes | Where-Object {
                    $rel = $_.RelativePath
                    if ($rel) { $rel = $rel.TrimStart('\','/') }
                    $excluded = $false
                    foreach ($pattern in $ExcludePatterns) {
                        if ($pattern -match '^[^*?]+(\\|/)?\*\*?$' -or $pattern -match '^[^*?]+$') {
                            $dirName = $pattern -replace '[\\/]*\*\*?$', ''
                            if ($rel -replace '/', '\' -match "(^|\\)" + [regex]::Escape($dirName) + "(\\|$)") {
                                $excluded = $true
                                break
                            }
                        } elseif ($rel -like $pattern) {
                            $excluded = $true
                            break
                        }
                    }
                    -not $excluded
                }
            }

            # Normalize entries to ensure stable keys for caching and JSON serialization
            $normalizedFiles = @()
            foreach ($h in $rawHashes) {
                if ($null -eq $h) { continue }

                # Normalise RelativePath
                $rel = $h.RelativePath
                if ($rel) { $rel = $rel.TrimStart('\','/') }

                if ($h.PSObject.Properties.Name -contains 'Size') {
                    $size = [long]$h.Size
                }
                elseif ($h.PSObject.Properties.Name -contains 'Length') {
                    $size = [long]$h.Length
                }
                else {
                    $size = 0
                }

                # Normalize LastWriteTime to consistent string with milliseconds
                $lwt = $h.LastWriteTime
                if ($lwt -is [DateTime]) {
                    $lwtStr = $lwt.ToString('yyyy-MM-dd HH:mm:ss.fff')
                }
                else {
                    try { $lwtStr = ([DateTime]::Parse($lwt)).ToString('yyyy-MM-dd HH:mm:ss.fff') }
                    catch { $lwtStr = $lwt.ToString() }
                }

                $fileObj = [PSCustomObject]@{
                    Path = $h.Path
                    RelativePath = $rel
                    Hash = $h.Hash
                    Algorithm = $h.Algorithm
                    Size = $size
                    LastWriteTime = $lwtStr
                }

                if ($h.PSObject.Properties.Name -contains 'CacheHit') {
                    $null = $fileObj | Add-Member -NotePropertyName 'CacheHit' -NotePropertyValue $h.CacheHit -PassThru
                }

                $normalizedFiles += $fileObj
            }

            # Calculate counts and totals from normalized entries
            $fileCount = $normalizedFiles.Count
            $totalSize = 0
            if ($fileCount -gt 0) { $totalSize = ($normalizedFiles | Measure-Object -Property Size -Sum).Sum }

            $state = [PSCustomObject]@{
                Timestamp = Get-Date -Format "o"
                SourcePath = (Resolve-Path $SourcePath).Path
                FileCount = $fileCount
                TotalSize = $totalSize
                Files = $normalizedFiles
            }
            
            # Rotate: latest -> prev
            if (Test-Path $latestFile) {
                Write-Verbose "Rotating latest.json to prev.json"
                Copy-Item -Path $latestFile -Destination $prevFile -Force
            }
            
            # Save new latest
            $state | ConvertTo-Json -Depth 10 | Set-Content -Path $latestFile -Encoding UTF8
            
            # Save backup-specific state if BackupName is provided
            if ($BackupName) {
                $backupStateFile = Join-Path $StateDirectory "$BackupName.json"
                $state | ConvertTo-Json -Depth 10 | Set-Content -Path $backupStateFile -Encoding UTF8
                Write-Verbose "Backup-specific state saved: $backupStateFile"
            }
            
            Write-Log -Message "Integrity state saved: $($state.FileCount) files tracked, $([math]::Round($state.TotalSize / 1MB, 2)) MB total" -Level Success
            
            return $state
        }
        catch {
            Write-Error "Failed to save integrity state: $_"
            throw
        }
    }
}