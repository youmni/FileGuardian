function New-BackupReport {
    <#
    .SYNOPSIS
        Generates and signs a backup report.
    
    .DESCRIPTION
        Helper function that generates a backup report in the specified format
        and optionally signs it with a digital signature.
    
    .PARAMETER BackupInfo
        Hashtable containing backup information.
    
    .PARAMETER ReportFormat
        Format for the report (JSON, HTML, or CSV).
    
    .PARAMETER ReportPath
        Optional custom path for the report.
    
    .OUTPUTS
        Hashtable with report information added.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BackupInfo,
        
        [Parameter()]
        [ValidateSet("JSON", "HTML", "CSV")]
        [string]$ReportFormat = "JSON",
        
        [Parameter()]
        [string]$ReportPath
    )
    
    try {
        Write-Log -Message "Generating backup report ($ReportFormat)..." -Level Info
        $signModule = Join-Path $PSScriptRoot "..\Reporting\Protect-Report.psm1"
        
        # Select report module based on format
        $reportModule = switch ($ReportFormat) {
            "JSON" { Join-Path $PSScriptRoot "..\Reporting\Write-JsonReport.psm1" }
            "HTML" { Join-Path $PSScriptRoot "..\Reporting\Write-HtmlReport.psm1" }
            "CSV"  { Join-Path $PSScriptRoot "..\Reporting\Write-CsvReport.psm1" }
            default { Join-Path $PSScriptRoot "..\Reporting\Write-JsonReport.psm1" }
        }
        
        if (-not (Test-Path $reportModule)) {
            Write-Log -Message "Report module not found: $reportModule" -Level Error
            $BackupInfo['ReportPath'] = $null
            $BackupInfo['ReportSigned'] = $false
            return $BackupInfo
        }
        
        Import-Module $reportModule -Force
        
        # Generate report based on format
        $reportInfo = switch ($ReportFormat) {
            "JSON" {
                if ($ReportPath) {
                    Write-JsonReport -BackupInfo ([PSCustomObject]$BackupInfo) -ReportPath $ReportPath
                } else {
                    Write-JsonReport -BackupInfo ([PSCustomObject]$BackupInfo)
                }
            }
            "HTML" {
                if ($ReportPath) {
                    Write-HtmlReport -BackupInfo ([PSCustomObject]$BackupInfo) -ReportPath $ReportPath
                } else {
                    Write-HtmlReport -BackupInfo ([PSCustomObject]$BackupInfo)
                }
            }
            "CSV" {
                if ($ReportPath) {
                    Write-CsvReport -BackupInfo ([PSCustomObject]$BackupInfo) -ReportPath $ReportPath
                } else {
                    Write-CsvReport -BackupInfo ([PSCustomObject]$BackupInfo)
                }
            }
        }
        
        if ($reportInfo -and $reportInfo.ReportPath) {
            $BackupInfo['ReportPath'] = $reportInfo.ReportPath
            $BackupInfo['ReportFormat'] = $ReportFormat
            Write-Log -Message "Report generated: $($reportInfo.ReportPath)" -Level Success
            
            if (Test-Path $signModule) {
                Import-Module $signModule -Force
                $signInfo = Protect-Report -ReportPath $reportInfo.ReportPath
                $BackupInfo['ReportSigned'] = $true
                $BackupInfo['ReportSignature'] = $signInfo.Hash
                Write-Log -Message "Report signed successfully" -Level Info
            }
        }
        else {
            $BackupInfo['ReportPath'] = $null
            $BackupInfo['ReportSigned'] = $false
        }
    }
    catch {
        Write-Log -Message "Failed to generate report: $_" -Level Error
        $BackupInfo['ReportPath'] = $null
        $BackupInfo['ReportSigned'] = $false
    }
    
    return $BackupInfo
}