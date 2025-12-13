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
            
            # Calculate current hash
            $currentHash = Get-FileHash -Path $ReportPath -Algorithm $signature.Algorithm
            
            # Compare
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
