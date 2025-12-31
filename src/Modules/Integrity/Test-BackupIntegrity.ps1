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
        
        # Try to find backup-specific state file first
        $backupItem = Get-Item $BackupPath
        $backupBaseName = if ($backupItem.Extension -eq '.zip') {
            $backupItem.BaseName
        } else {
            $backupItem.Name
        }
        
        $backupStateFile = Join-Path $StateDirectory "$backupBaseName.json"
        $latestFile = Join-Path $StateDirectory "latest.json"
        
        # Use backup-specific state if available, otherwise fall back to latest
        $stateFile = if (Test-Path $backupStateFile) {
            Write-Verbose "Using backup-specific state: $backupStateFile"
            $backupStateFile
        } else {
            Write-Verbose "No backup-specific state found, using latest.json"
            $latestFile
        }
    }
    
    Process {
        try {
            # Validate state file exists
            if (-not (Test-Path $stateFile)) {
                Write-Warning "No integrity state found at: $stateFile"
                return
            }
            
            # Load state
            Write-Verbose "Loading integrity state from: $stateFile"
            $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
                        
            # Check if backup is a ZIP file
            $isZip = $false
            $tempExtractPath = $null
            $pathToVerify = $BackupPath
            
            if ((Test-Path $BackupPath) -and (Get-Item $BackupPath).Extension -eq '.zip') {
                $isZip = $true
                Write-Log -Message "Backup is compressed (ZIP). Extracting for verification..." -Level Info
                Write-Verbose "Backup is a ZIP archive, extracting..."

                # Create temp directory for extraction (unique name to avoid collisions)
                $tempExtractPath = Join-Path $env:TEMP ("FileGuardian_Verify_{0}_{1}" -f (Get-Date -Format 'yyyyMMddHHmmss'), [IO.Path]::GetRandomFileName())
                New-Item -Path $tempExtractPath -ItemType Directory -Force | Out-Null

                # Show extraction progress stub and extract
                Write-Progress -Activity "Extracting backup" -Status "Extracting archive..." -PercentComplete 0
                Expand-Archive -Path $BackupPath -DestinationPath $tempExtractPath -Force
                Write-Progress -Activity "Extracting backup" -Completed

                $pathToVerify = $tempExtractPath

                Write-Log -Message "Extraction completed to temporary directory" -Level Info
                Write-Verbose "Extracted to: $tempExtractPath"
            }
            
            # Resolve backup path to absolute
            $absoluteBackupPath = (Resolve-Path $pathToVerify).Path
            
            # Check for backup metadata (for incremental backups)
            $metadataPath = Join-Path $absoluteBackupPath ".backup-metadata.json"
            $backupMetadata = $null
            $isIncrementalOrDifferential = $false
            
            if (Test-Path $metadataPath) {
                try {
                    $backupMetadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
                    $isIncrementalOrDifferential = ($backupMetadata.BackupType -eq "Incremental" -or $backupMetadata.BackupType -eq "Differential")
                    Write-Verbose "Detected $($backupMetadata.BackupType) backup"
                }
                catch {
                    Write-Warning "Could not read backup metadata: $_"
                }
            }
            else {
                Write-Verbose "No metadata found, assuming Full backup"
            }
            
            # Calculate current hashes for backup
            Write-Log -Message "Calculating current hashes for backup: $absoluteBackupPath" -Level Info
            Write-Progress -Activity "Verifying backup" -Status "Calculating hashes..." -PercentComplete 0
            $currentHashes = Get-FileIntegrityHash -Path $absoluteBackupPath -StateDirectory $StateDirectory -Recurse
            Write-Progress -Activity "Verifying backup" -Completed
            Write-Log -Message "Calculated current hashes: $($currentHashes.Count) files" -Level Info
            
            # Exclude metadata file from verification
            $currentHashes = $currentHashes | Where-Object { $_.RelativePath -ne ".backup-metadata.json" }
            
            # Create lookup tables
            $stateHash = @{}
            foreach ($file in $state.Files) {
                # Extract relative path from full path
                $relativePath = $file.RelativePath
                $stateHash[$relativePath] = $file
            }
            
            $currentHash = @{}
            foreach ($file in $currentHashes) {
                $relativePath = $file.RelativePath
                $currentHash[$relativePath] = $file
            }
            
            # Analyze integrity
            $corrupted = @()
            $missing = @()
            $extra = @()
            $verified = @()

            if ($isIncrementalOrDifferential -and $backupMetadata -and $backupMetadata.FilesIncluded) {
                foreach ($relPath in $backupMetadata.FilesIncluded) {
                    $normRel = $relPath -replace '/','\\'
                    if ($currentHash.ContainsKey($relPath)) {
                        $verified += $currentHash[$relPath]
                    }
                    elseif ($currentHash.ContainsKey($normRel)) {
                        $verified += $currentHash[$normRel]
                    }
                    else {
                        Write-Verbose "Missing included file from metadata: $relPath"
                        $missing += [PSCustomObject]@{ RelativePath = $relPath }
                    }
                }
            }
            
            # Check files in state
            foreach ($path in $stateHash.Keys) {
                if (-not $currentHash.ContainsKey($path)) {
                    if (-not $isIncrementalOrDifferential) {
                        $missing += $stateHash[$path]
                    }
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
                Corrupted = $corrupted
                Missing = $missing
                Extra = $extra
                Summary = [PSCustomObject]@{
                    VerifiedCount = $verified.Count
                    CorruptedCount = $corrupted.Count
                    MissingCount = $missing.Count
                    ExtraCount = $extra.Count
                    TotalSourceFiles = $state.FileCount
                }
            }
            
            # Log and display results
            Write-Host "`n=== Backup Integrity Verification ===" -ForegroundColor Cyan
            Write-Host "Backup:    $BackupPath" -ForegroundColor Gray
            Write-Host "State:     $($state.Timestamp)" -ForegroundColor Gray
            Write-Host ""
            
            if ($isIntact) {
                Write-Host "Status:    INTACT" -ForegroundColor Green
                Write-Host "All $($verified.Count) files verified successfully!" -ForegroundColor Green
                Write-Log -Message "Integrity verification: INTACT - All $($verified.Count) files verified" -Level Success
            }
            else {
                Write-Host "Status:    COMPROMISED" -ForegroundColor Red
                Write-Log -Message "Integrity verification: COMPROMISED - Verified: $($result.Summary.VerifiedCount), Corrupted: $($result.Summary.CorruptedCount), Missing: $($result.Summary.MissingCount)" -Level Error
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
                    Write-Log -Message "Corrupted file detected: $($file.Path)" -Level Error
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