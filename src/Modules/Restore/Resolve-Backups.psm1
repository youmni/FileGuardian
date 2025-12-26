function Resolve-Backups {
    <#
    .SYNOPSIS
        Read metadata for each candidate and normalize into objects.

    .PARAMETER BackupDirectory
        Directory that holds backup folders and/or zip archives.

    .OUTPUTS
        Array of PSCustomObject with properties: Path, IsZip, ExtractPath, Metadata, Timestamp
    #>
    param(
        [Parameter(Mandatory=$true)][string]$BackupDirectory
    )

    $candidates = Get-BackupCandidates -BackupDirectory $BackupDirectory
    $normalized = @()

    foreach ($c in $candidates) {
        if ($c -match '\.zip$') {
            $info = Get-MetadataFromZip -ZipPath $c
            $meta = $info.Metadata
            if (-not $meta.BackupType -or -not $meta.Timestamp) { throw "Invalid metadata in zip backup: $c" }
            $ts = Convert-BackupTimestampToDateTime -Timestamp $meta.Timestamp
            $normalized += [PSCustomObject]@{
                Path = $c
                IsZip = $true
                ExtractPath = $info.ExtractPath
                Metadata = $meta
                Timestamp = $ts
            }
        }
        else {
            $meta = Get-MetadataFromFolder -FolderPath $c
            if (-not $meta.BackupType -or -not $meta.Timestamp) { throw "Invalid metadata in folder backup: $c" }
            $ts = Convert-BackupTimestampToDateTime -Timestamp $meta.Timestamp
            $normalized += [PSCustomObject]@{
                Path = $c
                IsZip = $false
                ExtractPath = $null
                Metadata = $meta
                Timestamp = $ts
            }
        }
    }

    return $normalized
}