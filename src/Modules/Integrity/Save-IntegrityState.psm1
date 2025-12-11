function Save-IntegrityState {
    <#
    .SYNOPSIS
        Saves current integrity state to JSON file.
    
    .DESCRIPTION
        Captures file hashes and saves them to states/latest.json.
        Rotates previous latest to prev.json.
    
    .PARAMETER SourcePath
        Path to backup source directory to track.
    
    .PARAMETER StateDirectory
        Directory where state files are stored. Default is .\states
    
    .EXAMPLE
        Save-IntegrityState -SourcePath "C:\Data"
        Saves integrity state for C:\Data
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,
        
        [Parameter()]
        [string]$StateDirectory = ".\states"
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
            # Import Get-FileIntegrityHash module
            Import-Module (Join-Path $PSScriptRoot "Get-FileIntegrityHash.psm1") -Force
            
            # Get current hashes
            Write-Verbose "Calculating file hashes..."
            $hashes = Get-FileIntegrityHash -Path $SourcePath -Recurse
            
            # Create state object
            $state = [PSCustomObject]@{
                Timestamp = Get-Date -Format "o"
                SourcePath = (Resolve-Path $SourcePath).Path
                FileCount = $hashes.Count
                TotalSize = ($hashes | Measure-Object -Property Size -Sum).Sum
                Files = $hashes
            }
            
            # Rotate: latest -> prev
            if (Test-Path $latestFile) {
                Write-Verbose "Rotating latest.json to prev.json"
                Copy-Item -Path $latestFile -Destination $prevFile -Force
            }
            
            # Save new latest
            Write-Verbose "Saving new state to latest.json"
            $state | ConvertTo-Json -Depth 10 | Set-Content -Path $latestFile -Encoding UTF8
            
            Write-Host "Integrity state saved successfully" -ForegroundColor Green
            Write-Host "  Files tracked: $($state.FileCount)" -ForegroundColor Cyan
            Write-Host "  Total size: $([math]::Round($state.TotalSize / 1MB, 2)) MB" -ForegroundColor Cyan
            Write-Host "  State file: $latestFile" -ForegroundColor Cyan
            
            return $state
        }
        catch {
            Write-Error "Failed to save integrity state: $_"
            throw
        }
    }
}