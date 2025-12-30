function Convert-BackupTimestampToDateTime {
    <#
    .SYNOPSIS
        Convert backup timestamp string to DateTime.

    .PARAMETER Timestamp
        Timestamp in format yyyyMMdd_HHmmss (e.g. 20251225_165041)

    .OUTPUTS
        [datetime]
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Timestamp
    )

    try {
        return [datetime]::ParseExact($Timestamp, 'yyyyMMdd_HHmmss', $null)
    }
    catch {
        throw "Invalid backup timestamp format: $Timestamp. Expected 'yyyyMMdd_HHmmss'."
    }
}