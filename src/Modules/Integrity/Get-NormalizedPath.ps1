<#
.SYNOPSIS
    Normalize filesystem paths for consistent comparisons.

.DESCRIPTION
    Resolves the given path to its full path, converts to a consistent
    case (uppercase) and removes trailing backslashes except for root
    paths (e.g. C:\). This helper ensures stable path comparison across
    runs and platforms where casing may vary.

.PARAMETER PathToNormalize
    The path to resolve and normalize.

.EXAMPLE
    Get-NormalizedPath -PathToNormalize 'C:\Data\file.txt'

    Returns the normalized full path for the provided file.
#>
function Get-NormalizedPath {
    param([string]$PathToNormalize)

    # Resolve to full path and normalize
    $resolved = (Resolve-Path -Path $PathToNormalize -ErrorAction Stop).Path

    # Ensure consistent format: uppercase and no trailing backslash (except root)
    $normalized = $resolved.ToUpperInvariant()

    if ($normalized -notmatch '^[A-Z]:\\$') {
        $normalized = $normalized.TrimEnd('\\')
    }

    return $normalized
}
