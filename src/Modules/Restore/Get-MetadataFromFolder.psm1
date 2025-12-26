function Get-MetadataFromFolder {
    <#
    .SYNOPSIS
        Read `.backup-metadata.json` from a folder backup and convert to object.

    .PARAMETER FolderPath
        Path to the backup folder.

    .OUTPUTS
        PSCustomObject parsed from JSON
    #>
    param(
        [Parameter(Mandatory=$true)][string]$FolderPath
    )

    $metaPath = Join-Path $FolderPath '.backup-metadata.json'
    if (-not (Test-Path $metaPath)) {
        throw "Missing metadata file '.backup-metadata.json' in backup: $FolderPath"
    }

    try {
        $raw = Get-Content $metaPath -Raw
        return $raw | ConvertFrom-Json
    }
    catch {
        throw ("Failed to read or parse metadata in {0}: {1}" -f $FolderPath, $_.Exception.Message)
    }
}