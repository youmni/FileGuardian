function Invoke-Restore {
    <#
    .SYNOPSIS
        Apply a chain of backups (full + incrementals) into a restore directory.

    .PARAMETER Chain
        Array of normalized backup objects (Path, IsZip, ExtractPath, Metadata, Timestamp)

    .PARAMETER RestoreDirectory
        Destination directory where files will be restored.
    #>
    param(
        [array]$Chain,
        [string]$RestoreDirectory
    )

    if ($null -eq $Chain -or ($Chain -is [array] -and $Chain.Count -eq 0)) {
        throw "Parameter 'Chain' is required and must be a non-empty array."
    }

    if (-not $RestoreDirectory) {
        throw "Parameter 'RestoreDirectory' is required."
    }

    # Ensure the restore directory exists and is writable
    if (-not (Test-Path $RestoreDirectory)) {
        try { New-Item -Path $RestoreDirectory -ItemType Directory -Force | Out-Null }
        catch { throw ("Cannot create RestoreDirectory: {0}. {1}" -f $RestoreDirectory, $_.Exception.Message) }
    }

    $testFile = Join-Path $RestoreDirectory ([IO.Path]::GetRandomFileName())
    try { New-Item -Path $testFile -ItemType File -Force | Out-Null; Remove-Item $testFile -Force }
    catch { throw ("RestoreDirectory is not writable: {0}. {1}" -f $RestoreDirectory, $_.Exception.Message) }

    try {
        foreach ($backup in $Chain) {
            Write-Log -Message ("Applying backup: {0} (Type: {1})" -f $backup.Path, $backup.Metadata.BackupType) -Level Info

            $sourcePath = if ($backup.IsZip) { $backup.ExtractPath } else { $backup.Path }

            try {
                # copy all children of sourcePath into restore directory, overwriting existing
                Get-ChildItem -Path $sourcePath -Force | ForEach-Object {
                    $src = $_.FullName
                    $dest = Join-Path $RestoreDirectory $_.Name
                    if ($_.PSIsContainer) {
                        Copy-Item -Path $src -Destination $dest -Recurse -Force -ErrorAction Stop
                    }
                    else {
                        Copy-Item -Path $src -Destination $dest -Force -ErrorAction Stop
                    }
                }
            }
            catch {
                throw ("Failed to apply backup {0}: {1}" -f $backup.Path, $_.Exception.Message)
            }

            # Apply deletions declared in this backup's metadata (if any)
            if ($backup.Metadata -and $backup.Metadata.DeletedFiles) {
                $baseRestore = (Resolve-Path -Path $RestoreDirectory).Path
                foreach ($rel in $backup.Metadata.DeletedFiles) {
                    try {
                        # Normalize and ensure deletion stays inside restore directory
                        $candidate = Join-Path $RestoreDirectory $rel
                        $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
                        if (-not $resolved) {
                            # Path doesn't exist in restore target, nothing to remove
                            continue
                        }
                        $resolvedPath = $resolved.Path
                        if (-not ($resolvedPath.StartsWith($baseRestore, [System.StringComparison]::OrdinalIgnoreCase))) {
                            Write-Log -Message ("Skipping unsafe delete path: {0}" -f $resolvedPath) -Level Warning
                            continue
                        }

                        # Remove file or folder
                        if (Test-Path $resolvedPath) {
                            Remove-Item -Path $resolvedPath -Recurse -Force -ErrorAction Stop
                            Write-Log -Message ("Deleted path from restore per metadata: {0}" -f $rel) -Level Info
                        }
                    }
                    catch {
                        Write-Log -Message ("Failed to apply deletion '{0}': {1}" -f $rel, $_.Exception.Message) -Level Warning
                    }
                }
            }
        }
    }
    finally {
        # Cleanup extracted temp folders for zipped backups
        foreach ($b in $Chain | Where-Object { $_.IsZip -eq $true }) {
            if ($b.ExtractPath -and (Test-Path $b.ExtractPath)) {
                try { Remove-Item -Path $b.ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
                catch { Write-Verbose ("Failed to clean temp folder {0}: {1}" -f $b.ExtractPath, $_.Exception.Message) }
            }
        }

        # Remove any .backup-metadata.json files copied into the restore output
        try {
            Get-ChildItem -Path $RestoreDirectory -Recurse -Force -File | Where-Object { $_.Name -ieq '.backup-metadata.json' } | ForEach-Object {
                try { Remove-Item -Path $_.FullName -Force -ErrorAction Stop }
                catch { Write-Verbose ("Failed to remove metadata file {0}: {1}" -f $_.FullName, $_.Exception.Message) }
            }
        }
        catch {
            Write-Verbose ("Error while cleaning metadata files in restore output: {0}" -f $_.Exception.Message)
        }
    }

    return $true
}