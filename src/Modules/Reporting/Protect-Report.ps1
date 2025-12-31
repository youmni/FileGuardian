function Protect-Report {
    <#
    .SYNOPSIS
        Signs a report file using integrity hash.
    
    .DESCRIPTION
        Creates a cryptographic signature (hash) of a report file
        to verify it hasn't been tampered with later.
    
    .PARAMETER ReportPath
        Path to the report file to sign.
    
    .PARAMETER Algorithm
        Hash algorithm to use (SHA256, SHA1, MD5). Default is SHA256.

    .PARAMETER CredentialTarget
        The name of the credential target in Windows Credential Manager to use for signing.
        Default is "FileGuardian.ReportSigning".
        
    .EXAMPLE
        Protect-Report -ReportPath ".\reports\backup_report.json"
        Signs the report with SHA256
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ReportPath,

        [Parameter()]
        [ValidateSet("HMACSHA256", "HMACSHA1")]
        [string]$Algorithm = "HMACSHA256",

        [Parameter()]
        [string]$CredentialTarget = "FileGuardian.ReportSigning"
    )
    
    Process {
        try {
            Write-Log -Message "Signing report: $ReportPath" -Level Info
            
            $key = Get-ReportSigningKey -Target $CredentialTarget
            if (-not $key) { throw "Signing key could not be retrieved from Credential Manager for target '$CredentialTarget'" }
            $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)

            # Prepare metadata
            $reportFileLeaf = Split-Path $ReportPath -Leaf
            $signedAt = Get-Date -Format "o"
            $signedBy = "$env:USERNAME@$env:COMPUTERNAME"
            $credTargetValue = $CredentialTarget

            $metaString = "$reportFileLeaf|$Algorithm|$signedAt|$signedBy|$credTargetValue"
            $metaBytes = [System.Text.Encoding]::UTF8.GetBytes($metaString)

            # Read report bytes and concatenate with metadata bytes
            $reportBytes = [System.IO.File]::ReadAllBytes($ReportPath)
            $combined = New-Object byte[] ($reportBytes.Length + $metaBytes.Length)
            [Array]::Copy($reportBytes, 0, $combined, 0, $reportBytes.Length)
            [Array]::Copy($metaBytes, 0, $combined, $reportBytes.Length, $metaBytes.Length)

            switch ($Algorithm) {
                'HMACSHA256' { $hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes) }
                'HMACSHA1' { $hmac = [System.Security.Cryptography.HMACSHA1]::new($keyBytes) }
            }
            $hashBytes = $hmac.ComputeHash($combined)
            $hash = [PSCustomObject]@{ Hash = ([System.BitConverter]::ToString($hashBytes)).Replace('-','').ToLowerInvariant() }
            
            # Create signature file path
            $signaturePath = "$ReportPath.sig"
            
            # Build signature content
            $signature = [PSCustomObject]@{
                ReportFile = $reportFileLeaf
                Algorithm = $Algorithm
                Hash = $hash.Hash
                SignedAt = $signedAt
                SignedBy = $signedBy
                CredentialTarget = $credTargetValue
            }
            
            # Save signature
            $signature | ConvertTo-Json | Out-File -FilePath $signaturePath -Encoding UTF8 -Force
            
            Write-Log -Message "Report signed successfully with $Algorithm (Hash: $($hash.Hash.Substring(0, 16))...)" -Level Success
            
            return [PSCustomObject]@{
                ReportPath = $ReportPath
                SignaturePath = $signaturePath
                Algorithm = $Algorithm
                Hash = $hash.Hash
                SignedAt = Get-Date
            }
        }
        catch {
            Write-Error "Failed to sign report: $_"
            throw
        }
    }
}