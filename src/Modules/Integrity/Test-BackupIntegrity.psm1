function Test-BackupIntegrity {
    <#
    .SYNOPSIS
        Verifies backup integrity against saved state.
    
    .DESCRIPTION
        Compares current file hashes in backup with the saved state
        to detect corruption or tampering.
    
    .PARAMETER BackupPath
        Path to the backup directory to verify.
    
    .PARAMETER StateDirectory
        Directory where state files are stored. Default is .\states
    
    .EXAMPLE
        Test-BackupIntegrity -BackupPath ".\backups\TestBackup_20251211_202254"
        Verifies backup integrity
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$BackupPath,
        
        [Parameter()]
        [string]$StateDirectory
    )
    
    Begin {
        Write-Verbose "Verifying backup integrity for: $BackupPath"
        
        # If StateDirectory not specified, look for it relative to backup
        if (-not $StateDirectory) {
            $backupParent = Split-Path $BackupPath -Parent
            $StateDirectory = Join-Path $backupParent "states"
        }
        
        $latestFile = Join-Path $StateDirectory "latest.json"
    }
    
    Process {
        try {
            # Validate state file exists
            if (-not (Test-Path $latestFile)) {
                Write-Warning "No integrity state found at: $latestFile"
                return
            }
            
            # Load state
            Write-Verbose "Loading integrity state..."
            $state = Get-Content -Path $latestFile -Raw | ConvertFrom-Json
            
            # Import Get-FileIntegrityHash
            Import-Module (Join-Path $PSScriptRoot "Get-FileIntegrityHash.psm1") -Force
            
            # Check if backup is a ZIP file
            $isZip = $false
            $tempExtractPath = $null
            $pathToVerify = $BackupPath
            
            if ((Test-Path $BackupPath) -and (Get-Item $BackupPath).Extension -eq '.zip') {
                $isZip = $true
                Write-Verbose "Backup is a ZIP archive, extracting..."
                
                # Create temp directory for extraction
                $tempExtractPath = Join-Path $env:TEMP "FileGuardian_Verify_$(Get-Date -Format 'yyyyMMddHHmmss')"
                New-Item -Path $tempExtractPath -ItemType Directory -Force | Out-Null
                
                # Extract ZIP
                Expand-Archive -Path $BackupPath -DestinationPath $tempExtractPath -Force
                $pathToVerify = $tempExtractPath
                
                Write-Verbose "Extracted to: $tempExtractPath"
            }
            
            # Resolve backup path to absolute
            $absoluteBackupPath = (Resolve-Path $pathToVerify).Path
            
            # Calculate current hashes for backup
            Write-Verbose "Calculating current hashes for backup..."
            $currentHashes = Get-FileIntegrityHash -Path $absoluteBackupPath -Recurse
            
            # Create lookup tables
            $stateHash = @{}
            foreach ($file in $state.Files) {
                # Extract relative path from full path
                $relativePath = $file.RelativePath
                $stateHash[$relativePath] = $file
            }
            
            $currentHash = @{}
            foreach ($file in $currentHashes) {
                # Use the RelativePath property directly (already calculated correctly)
                $relativePath = $file.RelativePath
                $currentHash[$relativePath] = $file
            }
            
            # Analyze integrity
            $corrupted = @()
            $missing = @()
            $extra = @()
            $verified = @()
            
            # Check files in state
            foreach ($path in $stateHash.Keys) {
                if (-not $currentHash.ContainsKey($path)) {
                    $missing += $stateHash[$path]
                }
                elseif ($currentHash[$path].Hash -ne $stateHash[$path].Hash) {
                    $corrupted += [PSCustomObject]@{
                        Path = $path
                        ExpectedHash = $stateHash[$path].Hash
                        ActualHash = $currentHash[$path].Hash
                        ExpectedSize = $stateHash[$path].Size
                        ActualSize = $currentHash[$path].Size
                    }
                }
                else {
                    $verified += $currentHash[$path]
                }
            }
            
            # Check for extra files
            foreach ($path in $currentHash.Keys) {
                if (-not $stateHash.ContainsKey($path)) {
                    $extra += $currentHash[$path]
                }
            }
            
            # Determine overall status
            $isIntact = ($corrupted.Count -eq 0 -and $missing.Count -eq 0 -and $extra.Count -eq 0)
            
            # Create result
            $result = [PSCustomObject]@{
                BackupPath = $BackupPath
                StateTimestamp = $state.Timestamp
                IsIntact = $isIntact
                Verified = $verified
                Corrupted = $corrupted
                Missing = $missing
                Extra = $extra
                Summary = [PSCustomObject]@{
                    VerifiedCount = $verified.Count
                    CorruptedCount = $corrupted.Count
                    MissingCount = $missing.Count
                    ExtraCount = $extra.Count
                    TotalFiles = $state.FileCount
                }
            }
            
            # Display results
            Write-Host "`n=== Backup Integrity Verification ===" -ForegroundColor Cyan
            Write-Host "Backup:    $BackupPath" -ForegroundColor Gray
            Write-Host "State:     $($state.Timestamp)" -ForegroundColor Gray
            Write-Host ""
            
            if ($isIntact) {
                Write-Host "Status:    INTACT" -ForegroundColor Green
                Write-Host "All $($verified.Count) files verified successfully!" -ForegroundColor Green
            }
            else {
                Write-Host "Status:    COMPROMISED" -ForegroundColor Red
                Write-Host ""
                Write-Host "Summary:" -ForegroundColor White
                Write-Host "  Verified:  $($result.Summary.VerifiedCount) files" -ForegroundColor Green
                Write-Host "  Corrupted: $($result.Summary.CorruptedCount) files" -ForegroundColor Red
                Write-Host "  Missing:   $($result.Summary.MissingCount) files" -ForegroundColor Yellow
                Write-Host "  Extra:     $($result.Summary.ExtraCount) files" -ForegroundColor Magenta
            }
            
            if ($corrupted.Count -gt 0) {
                Write-Host "`nCorrupted Files:" -ForegroundColor Red
                foreach ($file in $corrupted) {
                    Write-Host "  ! $($file.Path)" -ForegroundColor Red
                    Write-Host "    Expected: $($file.ExpectedHash)" -ForegroundColor Gray
                    Write-Host "    Actual:   $($file.ActualHash)" -ForegroundColor Gray
                }
            }
            
            if ($missing.Count -gt 0) {
                Write-Host "`nMissing Files:" -ForegroundColor Yellow
                foreach ($file in $missing) {
                    Write-Host "  ? $($file.RelativePath)" -ForegroundColor Yellow
                }
            }
            
            if ($extra.Count -gt 0) {
                Write-Host "`nExtra Files (not in state):" -ForegroundColor Magenta
                foreach ($file in $extra) {
                    Write-Host "  + $($file.RelativePath)" -ForegroundColor Magenta
                }
            }
            
            return $result
        }
        catch {
            Write-Error "Failed to verify backup integrity: $_"
            throw
        }
        finally {
            # Clean up temp directory if ZIP was extracted
            if ($tempExtractPath -and (Test-Path $tempExtractPath)) {
                Write-Verbose "Cleaning up temp directory: $tempExtractPath"
                Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}