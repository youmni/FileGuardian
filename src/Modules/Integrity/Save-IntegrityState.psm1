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
        [string]$BackupName
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