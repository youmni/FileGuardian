function Write-JsonReport {
    <#
    .SYNOPSIS
        Generates a JSON backup report.
    
    .DESCRIPTION
        Creates a detailed JSON report containing backup metadata, statistics,
        and integrity information.
    
    .PARAMETER BackupInfo
        Hashtable or PSCustomObject containing backup information.
    
    .PARAMETER ReportPath
        Path where the report will be saved. If not specified, saves to reports folder.
    
    .EXAMPLE
        Write-JsonReport -BackupInfo $backupResult -ReportPath ".\reports\backup_report.json"
        Generates a JSON report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$BackupInfo,
        
        [Parameter()]
        [string]$ReportPath
    )
    
    Begin {
        Write-Log -Message "Generating JSON backup report..." -Level Info
        
        # If no report path specified, create one
        if (-not $ReportPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $reportDir = ".\reports"
            
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            $backupName = if ($BackupInfo.BackupName) { $BackupInfo.BackupName } else { "backup" }
            $ReportPath = Join-Path $reportDir "${backupName}_${timestamp}_report.json"
        }
    }
    
    Process {
        try {
            # Ensure report directory exists
            $reportDir = Split-Path $ReportPath -Parent
            if ($reportDir -and -not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # Build comprehensive report
            $report = [PSCustomObject]@{
                ReportMetadata = [PSCustomObject]@{
                    GeneratedAt = Get-Date -Format "o"
                    ReportVersion = "1.0"
                    Generator = "FileGuardian"
                }
                BackupDetails = [PSCustomObject]@{
                    BackupName = $BackupInfo.BackupName
                    Type = $BackupInfo.Type
                    Timestamp = $BackupInfo.Timestamp
                    Duration = if ($BackupInfo.Duration) { $BackupInfo.Duration.ToString() } else { $null }
                    Success = $true
                }
                Paths = [PSCustomObject]@{
                    SourcePath = $BackupInfo.SourcePath
                    DestinationPath = $BackupInfo.DestinationPath
                }
                Statistics = [PSCustomObject]@{
                    FilesBackedUp = $BackupInfo.FilesBackedUp
                    TotalSizeMB = $BackupInfo.TotalSizeMB
                    Compressed = $BackupInfo.Compressed
                    CompressedSizeMB = $BackupInfo.CompressedSizeMB
                    CompressionRatio = $BackupInfo.CompressionRatio
                }
                Integrity = [PSCustomObject]@{
                    StateSaved = $BackupInfo.IntegrityStateSaved
                    StateDirectory = if ($BackupInfo.DestinationPath) { 
                        Join-Path $BackupInfo.DestinationPath "states" 
                    } else { 
                        $null 
                    }
                }
                PreviousBackupsVerification = [PSCustomObject]@{
                    TotalVerified = if ($BackupInfo.PreviousBackupsVerified) { $BackupInfo.PreviousBackupsVerified } else { 0 }
                    VerifiedOK = if ($BackupInfo.VerifiedBackupsOK) { $BackupInfo.VerifiedBackupsOK } else { 0 }
                    CorruptedCount = if ($BackupInfo.CorruptedBackups) { $BackupInfo.CorruptedBackups.Count } else { 0 }
                    CorruptedBackups = if ($BackupInfo.CorruptedBackups) { $BackupInfo.CorruptedBackups } else { @() }
                }
                SystemInfo = [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    UserName = $env:USERNAME
                    OSVersion = [System.Environment]::OSVersion.VersionString
                    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                }
            }
            
            # Convert to JSON with formatting
            $jsonContent = $report | ConvertTo-Json -Depth 10
            
            # Save report
            $jsonContent | Out-File -FilePath $ReportPath -Encoding UTF8 -Force
            
            Write-Host "`nBackup report generated:" -ForegroundColor Green
            Write-Host "  Location: $ReportPath" -ForegroundColor Gray
            
            # Return report info
            return [PSCustomObject]@{
                ReportPath = $ReportPath
                Format = "JSON"
                GeneratedAt = Get-Date
                Size = (Get-Item $ReportPath).Length
            }
        }
        catch {
            Write-Error "Failed to generate JSON report: $_"
            throw
        }
    }
}