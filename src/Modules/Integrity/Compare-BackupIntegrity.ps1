function Compare-BackupIntegrity {
    <#
    .SYNOPSIS
        Compares current state with previous integrity state.
    
    .DESCRIPTION
        Reads latest.json and prev.json to detect changes, additions, and deletions.
        Validates file integrity by comparing hashes.
    
    .PARAMETER StateDirectory
        Directory where state files are stored. Default is .\states
    
    .PARAMETER ShowUnchanged
        Show files that haven't changed.
    
    .EXAMPLE
        Compare-BackupIntegrity
        Compares current and previous integrity states
    
    .EXAMPLE
        Compare-BackupIntegrity -ShowUnchanged
        Shows all files including unchanged ones
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$StateDirectory = ".\states",
        
        [Parameter()]
        [switch]$ShowUnchanged
    )
    
    Begin {
        Write-Log -Message "Comparing integrity states in: $StateDirectory" -Level Info
        
        $latestFile = Join-Path $StateDirectory "latest.json"
        $prevFile = Join-Path $StateDirectory "prev.json"
    }
    
    Process {
        try {
            # Validate state files exist
            if (-not (Test-Path $latestFile)) {
                Write-Warning "No latest state found. Run Save-IntegrityState first."
                return
            }
            
            if (-not (Test-Path $prevFile)) {
                Write-Warning "No previous state found. This is the first snapshot."
                return
            }
            
            # Load states
            $latest = Get-Content -Path $latestFile -Raw | ConvertFrom-Json
            $prev = Get-Content -Path $prevFile -Raw | ConvertFrom-Json
            
            # Create hashtables for comparison
            $latestHash = @{}
            foreach ($file in $latest.Files) {
                $latestHash[$file.RelativePath] = $file
            }
            
            $prevHash = @{}
            foreach ($file in $prev.Files) {
                $prevHash[$file.RelativePath] = $file
            }
            
            # Analyze changes
            $added = @()
            $modified = @()
            $deleted = @()
            $unchanged = @()
            
            # Check for additions and modifications
            foreach ($path in $latestHash.Keys) {
                if (-not $prevHash.ContainsKey($path)) {
                    $added += $latestHash[$path]
                }
                elseif ($latestHash[$path].Hash -ne $prevHash[$path].Hash) {
                    $modified += [PSCustomObject]@{
                        Path = $latestHash[$path].RelativePath
                        PreviousHash = $prevHash[$path].Hash
                        CurrentHash = $latestHash[$path].Hash
                        PreviousSize = $prevHash[$path].Size
                        CurrentSize = $latestHash[$path].Size
                        PreviousModified = $prevHash[$path].LastWriteTime
                        CurrentModified = $latestHash[$path].LastWriteTime
                    }
                }
                else {
                    $unchanged += $latestHash[$path]
                }
            }
            
            # Check for deletions
            foreach ($path in $prevHash.Keys) {
                if (-not $latestHash.ContainsKey($path)) {
                    $deleted += $prevHash[$path]
                }
            }
            
            # Create comparison result
            $result = [PSCustomObject]@{
                PreviousTimestamp = $prev.Timestamp
                LatestTimestamp = $latest.Timestamp
                Added = $added
                Modified = $modified
                Deleted = $deleted
                Unchanged = $unchanged
                Summary = [PSCustomObject]@{
                    AddedCount = $added.Count
                    ModifiedCount = $modified.Count
                    DeletedCount = $deleted.Count
                    UnchangedCount = $unchanged.Count
                    TotalFiles = $latestHash.Count
                }
            }
            
            Write-Log -Message "Integrity comparison complete: Added: $($added.Count), Modified: $($modified.Count), Deleted: $($deleted.Count), Unchanged: $($unchanged.Count)" -Level Info
            
            # Display results
            Write-Host "`n=== Integrity Comparison ===" -ForegroundColor Cyan
            Write-Host "Previous: $($prev.Timestamp)" -ForegroundColor Gray
            Write-Host "Latest:   $($latest.Timestamp)" -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "Summary:" -ForegroundColor White
            Write-Host "  Added:     $($result.Summary.AddedCount) files" -ForegroundColor Green
            Write-Host "  Modified:  $($result.Summary.ModifiedCount) files" -ForegroundColor Yellow
            Write-Host "  Deleted:   $($result.Summary.DeletedCount) files" -ForegroundColor Red
            Write-Host "  Unchanged: $($result.Summary.UnchangedCount) files" -ForegroundColor Gray
            
            if ($added.Count -gt 0) {
                Write-Host "`nAdded Files:" -ForegroundColor Green
                foreach ($file in $added) {
                    Write-Host "  + $($file.RelativePath)" -ForegroundColor Green
                }
            }
            
            if ($modified.Count -gt 0) {
                Write-Host "`nModified Files:" -ForegroundColor Yellow
                foreach ($file in $modified) {
                    Write-Host "  ~ $($file.Path)" -ForegroundColor Yellow
                }
            }
            
            if ($deleted.Count -gt 0) {
                Write-Host "`nDeleted Files:" -ForegroundColor Red
                foreach ($file in $deleted) {
                    Write-Host "  - $($file.RelativePath)" -ForegroundColor Red
                }
            }
            
            if ($ShowUnchanged -and $unchanged.Count -gt 0) {
                Write-Host "`nUnchanged Files:" -ForegroundColor Gray
                foreach ($file in $unchanged) {
                    Write-Host "  = $($file.RelativePath)" -ForegroundColor Gray
                }
            }
            
            return $result
        }
        catch {
            Write-Error "Failed to compare integrity: $_"
            throw
        }
    }
}