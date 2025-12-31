function Confirm-ReportSignature {
    <#
    .SYNOPSIS
        Verifies a report's signature.
    
    .DESCRIPTION
        Checks if a report file matches its signature to detect tampering.
    
    .PARAMETER ReportPath
        Path to the report file to verify.
    
    .EXAMPLE
        Confirm-ReportSignature -ReportPath ".\reports\backup_report.json"
        Verifies the report signature
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ReportPath
    )
    
    Process {
        try {
            Write-Log -Message "Verifying report signature: $(Split-Path $ReportPath -Leaf)" -Level Info
            $signaturePath = "$ReportPath.sig"
            
            if (-not (Test-Path $signaturePath)) {
                Write-Warning "No signature file found for: $ReportPath"
                Write-Log -Message "No signature file found for: $(Split-Path $ReportPath -Leaf)" -Level Warning
                return $false
            }
            
            # Load signature
            $signature = Get-Content -Path $signaturePath -Raw | ConvertFrom-Json
            
            if (-not ($signature.Algorithm -and ($signature.Algorithm -like 'HMAC*'))) {
                Write-Error "Report signature algorithm is not HMAC."
                throw "Unsupported signature algorithm: $($signature.Algorithm)"
            }

            $credentialTarget = if ($signature.CredentialTarget) { $signature.CredentialTarget } else { 'FileGuardian.ReportSigning' }
            $key = Get-ReportSigningKey -Target $credentialTarget
            if (-not $key) { throw "Signing key could not be retrieved from Credential Manager for target '$credentialTarget'" }
            $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)

            $reportFileLeaf = $signature.ReportFile
            $signedAt = $signature.SignedAt
            $signedBy = $signature.SignedBy
            $credTargetValue = $credentialTarget
            $metaString = "$reportFileLeaf|$($signature.Algorithm)|$signedAt|$signedBy|$credTargetValue"
            $metaBytes = [System.Text.Encoding]::UTF8.GetBytes($metaString)

            # Read report bytes and concatenate with metadata bytes
            $reportBytes = [System.IO.File]::ReadAllBytes($ReportPath)
            $combined = New-Object byte[] ($reportBytes.Length + $metaBytes.Length)
            [Array]::Copy($reportBytes, 0, $combined, 0, $reportBytes.Length)
            [Array]::Copy($metaBytes, 0, $combined, $reportBytes.Length, $metaBytes.Length)

            switch ($signature.Algorithm) {
                'HMACSHA256' { $hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes) }
                'HMACSHA1' { $hmac = [System.Security.Cryptography.HMACSHA1]::new($keyBytes) }
            }
            $hashBytes = $hmac.ComputeHash($combined)
            $currentHash = [PSCustomObject]@{ Hash = ([System.BitConverter]::ToString($hashBytes)).Replace('-','').ToLowerInvariant() }

            $isValid = ($currentHash.Hash -eq $signature.Hash)
            
            if ($isValid) {
                Write-Host "`nReport signature is VALID" -ForegroundColor Green
                Write-Host "  Report: $(Split-Path $ReportPath -Leaf)" -ForegroundColor Gray
                Write-Host "  Signed: $($signature.SignedAt)" -ForegroundColor Gray
                Write-Host "  By: $($signature.SignedBy)" -ForegroundColor Gray
                Write-Log -Message "Report signature verified: VALID - $(Split-Path $ReportPath -Leaf)" -Level Success
            }
            else {
                Write-Host "`nReport signature is INVALID - Report has been modified!" -ForegroundColor Red
                Write-Host "  Expected: $($signature.Hash)" -ForegroundColor Gray
                Write-Host "  Actual:   $($currentHash.Hash)" -ForegroundColor Gray
                Write-Log -Message "Report signature verification: INVALID - $(Split-Path $ReportPath -Leaf) has been tampered!" -Level Error
            }
            
            return [PSCustomObject]@{
                ReportPath = $ReportPath
                IsValid = $isValid
                ExpectedHash = $signature.Hash
                ActualHash = $currentHash.Hash
                Algorithm = $signature.Algorithm
                SignedAt = $signature.SignedAt
                SignedBy = $signature.SignedBy
            }
        }
        catch {
            Write-Error "Failed to verify report signature: $_"
            throw
        }
    }
}