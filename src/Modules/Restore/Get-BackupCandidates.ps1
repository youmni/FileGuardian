function Get-BackupCandidates {
    <#
    .SYNOPSIS
        List folders and .zip files directly under a backup directory.

    .PARAMETER BackupDirectory
        Directory that holds backup folders and/or zip archives.

    .OUTPUTS
        Array of full paths (strings)
    #>
    param(
        [Parameter(Mandatory=$true)][string]$BackupDirectory
    )

    if (-not (Test-Path $BackupDirectory)) { throw "BackupDirectory not found: $BackupDirectory" }

    $items = @()
    Get-ChildItem -Path $BackupDirectory -File -Force | Where-Object { $_.Extension -eq '.zip' } | ForEach-Object {
        $items += $_.FullName
    }
    Get-ChildItem -Path $BackupDirectory -Directory -Force | ForEach-Object {
        # Skip state folders
        if ($_.Name -ieq 'states') { return }
        $items += $_.FullName
    }

    return $items
}