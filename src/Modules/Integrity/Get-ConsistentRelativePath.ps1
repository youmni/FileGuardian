<#
.SYNOPSIS
    Calculate a consistent relative path between a base and full path.

.DESCRIPTION
    Uses `Get-NormalizedPath` to normalize both the base path and the full
    file path, verifies that the full path is under the base path, and
    returns a relative path preserving the original filesystem casing.

.PARAMETER BasePath
    The base directory path to which the relative path should be calculated.

.PARAMETER FullPath
    The full file path for which a relative path will be returned.

.EXAMPLE
    Get-ConsistentRelativePath -BasePath 'C:\Data' -FullPath 'C:\Data\file.txt'

    Returns 'file.txt'.
#>
function Get-ConsistentRelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    # Normalize both paths for comparison
    $baseNormalized = Get-NormalizedPath -PathToNormalize $BasePath
    $fullNormalized = Get-NormalizedPath -PathToNormalize $FullPath

    if (-not $fullNormalized.StartsWith($baseNormalized, [StringComparison]::OrdinalIgnoreCase)) {
        throw "File path '$FullPath' is not under base path '$BasePath'"
    }

    # Calculate relative path
    $relativePath = $fullNormalized.Substring($baseNormalized.Length).TrimStart([char]'\\',[char]'/')
    $relativePathOriginalCase = $FullPath.Substring($BasePath.Length).TrimStart([char]'\\',[char]'/')

    return $relativePathOriginalCase
}
