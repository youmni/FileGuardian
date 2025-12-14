function Write-CsvReport {
    <#
    .SYNOPSIS
        Generates a CSV backup report.
    
    .DESCRIPTION
        Creates a detailed CSV report containing backup metadata and statistics.
        CSV format is ideal for importing into Excel or other data analysis tools.
    
    .PARAMETER BackupInfo
        Hashtable or PSCustomObject containing backup information.
    
    .PARAMETER ReportPath
        Path where the report will be saved. If not specified, saves to reports folder.
    
    .EXAMPLE
        Write-CsvReport -BackupInfo $backupResult -ReportPath ".\reports\backup_report.csv"
        Generates a CSV report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$BackupInfo,
        
        [Parameter()]
        [string]$ReportPath
    )
    
    Begin {
        Write-Log -Message "Generating CSV backup report..." -Level Info
        
        # If no report path specified, create one
        if (-not $ReportPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $reportDir = ".\reports"
            
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            $backupName = if ($BackupInfo.BackupName) { $BackupInfo.BackupName } else { "backup" }
            $ReportPath = Join-Path $reportDir "${backupName}_${timestamp}_report.csv"
        }
    }
    
    Process {
        try {
            # Ensure report directory exists
            $reportDir = Split-Path $ReportPath -Parent
            if ($reportDir -and -not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # Prepare data for CSV
            $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $duration = if ($BackupInfo.Duration) { $BackupInfo.Duration.ToString() } else { "N/A" }
            $compressed = if ($BackupInfo.Compressed) { "Yes" } else { "No" }
            $compressedSize = if ($BackupInfo.Compressed -and $BackupInfo.CompressedSizeMB) { 
                $BackupInfo.CompressedSizeMB
            } else { 
                "N/A" 
            }
            $compressionRatio = if ($BackupInfo.CompressionRatio) { 
                $BackupInfo.CompressionRatio
            } else { 
                "N/A" 
            }
            $integrityStateSaved = if ($BackupInfo.IntegrityStateSaved) { "Yes" } else { "No" }
            $stateDir = if ($BackupInfo.DestinationPath) { 
                Join-Path $BackupInfo.DestinationPath "states" 
            } else { 
                "N/A" 
            }
            
            # Build CSV data object
            $csvData = [PSCustomObject]@{
                # Report Metadata
                ReportGeneratedAt = $generatedAt
                ReportVersion = "1.0"
                Generator = "FileGuardian"
                
                # Backup Details
                BackupName = $BackupInfo.BackupName
                BackupType = $BackupInfo.Type
                BackupTimestamp = $BackupInfo.Timestamp
                Duration = $duration
                Status = "Success"
                
                # Paths
                SourcePath = $BackupInfo.SourcePath
                DestinationPath = $BackupInfo.DestinationPath
                
                # Statistics
                FilesBackedUp = $BackupInfo.FilesBackedUp
                TotalSizeMB = $BackupInfo.TotalSizeMB
                Compressed = $compressed
                CompressedSizeMB = $compressedSize
                CompressionRatio = $compressionRatio
                
                # Integrity
                IntegrityStateSaved = $integrityStateSaved
                IntegrityStateDirectory = $stateDir
                
                # Previous Backups Verification
                PreviousBackupsVerified = if ($BackupInfo.PreviousBackupsVerified) { $BackupInfo.PreviousBackupsVerified } else { 0 }
                VerifiedBackupsOK = if ($BackupInfo.VerifiedBackupsOK) { $BackupInfo.VerifiedBackupsOK } else { 0 }
                CorruptedBackupsCount = if ($BackupInfo.CorruptedBackups) { $BackupInfo.CorruptedBackups.Count } else { 0 }
                CorruptedBackupsList = if ($BackupInfo.CorruptedBackups -and $BackupInfo.CorruptedBackups.Count -gt 0) { 
                    ($BackupInfo.CorruptedBackups | ForEach-Object { "$($_.BackupName) (C:$($_.CorruptedFiles) M:$($_.MissingFiles))" }) -join "; " 
                } else { 
                    "None" 
                }
                
                # System Info
                ComputerName = $env:COMPUTERNAME
                UserName = $env:USERNAME
                OSVersion = [System.Environment]::OSVersion.VersionString
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            }
            
            # Export to CSV
            $csvData | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8 -Force
            
            Write-Host "`nBackup report generated:" -ForegroundColor Green
            Write-Host "  Location: $ReportPath" -ForegroundColor Gray
            Write-Host "  Format: CSV" -ForegroundColor Gray
            
            # Return report info
            return [PSCustomObject]@{
                ReportPath = $ReportPath
                Format = "CSV"
                GeneratedAt = Get-Date
                Size = (Get-Item $ReportPath).Length
            }
        }
        catch {
            Write-Error "Failed to generate CSV report: $_"
            throw
        }
    }
}
