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

    if (-not (Test-Path $ZipPath)) { 
        throw "Zip file not found: $ZipPath" 
    }
    
    $temp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
    
    try {
        New-Item -Path $temp -ItemType Directory -ErrorAction Stop | Out-Null
        
        try {
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $temp -Force -ErrorAction Stop
        }
        catch {
            throw ("Failed to extract zip '{0}': {1}" -f $ZipPath, $_.Exception.Message)
        }

        try {
            $metadata = Get-MetadataFromFolder -FolderPath $temp
        }
        catch {
            throw ("Failed to read metadata from extracted zip '{0}': {1}" -f $ZipPath, $_.Exception.Message)
        }
        
        return @{ 
            ExtractPath = $temp
            Metadata = $metadata 
        }
    }
    catch {
        # Cleanup temp folder if anything fails
        if (Test-Path $temp) {
            try {
                Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Failed to cleanup temp extraction folder: $temp" -Level Warning
            }
        }
        throw
    }
}