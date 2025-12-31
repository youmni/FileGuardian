function Get-ReportSigningKey {
    <#
    .SYNOPSIS
        Retrieves the report signing key from Windows Credential Manager.

    .DESCRIPTION
        Uses the CredentialManager module to fetch a stored secret that
        will be used as HMAC key for signing/verifying reports.

    .PARAMETER Target
        The credential target name in Windows Credential Manager.

    .EXAMPLE
        Get-ReportSigningKey -Target "FileGuardian.ReportSigning"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Target = "FileGuardian.ReportSigning"
    )

    Process {
        try {
            $cred = Get-StoredCredential -Target $Target -ErrorAction SilentlyContinue
            if (-not $cred) {
                Write-Error "No stored credential found for target '$Target'. Use New-StoredCredential to add one."
                throw "Missing stored credential for target: $Target"
            }

            return $cred.Password
        }
        catch {
            throw
        }
    }
}