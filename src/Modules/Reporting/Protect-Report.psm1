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
        [ValidateSet("SHA256", "SHA1", "MD5")]
        [string]$Algorithm = "SHA256"
    )
    
    Process {
        try {
            Write-Log -Message "Signing report: $ReportPath" -Level Info
            
            # Calculate hash of report
            $hash = Get-FileHash -Path $ReportPath -Algorithm $Algorithm
            
            # Create signature file path
            $signaturePath = "$ReportPath.sig"
            
            # Build signature content
            $signature = [PSCustomObject]@{
                ReportFile = Split-Path $ReportPath -Leaf
                Algorithm = $Algorithm
                Hash = $hash.Hash
                SignedAt = Get-Date -Format "o"
                SignedBy = "$env:USERNAME@$env:COMPUTERNAME"
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