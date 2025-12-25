function Get-MetadataFromZip {
    <#
    .SYNOPSIS
        Extract a zip to a temp folder, read metadata and return both.

    .PARAMETER ZipPath
        Path to the zip archive containing a backup.

    .OUTPUTS
        Hashtable with keys: ExtractPath, Metadata
    #>
    param(
        [Parameter(Mandatory=$true)][string]$ZipPath
    )

    if (-not (Test-Path $ZipPath)) { throw "Zip file not found: $ZipPath" }
    $temp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
    New-Item -Path $temp -ItemType Directory | Out-Null
    try {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $temp -Force
    }
    catch {
        Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
        throw ("Failed to extract zip '{0}': {1}" -f $ZipPath, $_.Exception.Message)
    }

    try {
        $metadata = Get-MetadataFromFolder -FolderPath $temp
        return @{ ExtractPath = $temp; Metadata = $metadata }
    }
    catch {
        Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}