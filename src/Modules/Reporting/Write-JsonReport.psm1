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
        # If ReportPath is a directory or has no extension (assume directory), generate filename
        elseif ((Test-Path $ReportPath -PathType Container) -or (-not [System.IO.Path]::HasExtension($ReportPath))) {
            # Create directory if it doesn't exist
            if (-not (Test-Path $ReportPath)) {
                New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
            }
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupName = if ($BackupInfo.BackupName) { $BackupInfo.BackupName } else { "backup" }
            $ReportPath = Join-Path $ReportPath "${backupName}_${timestamp}_report.json"
        }
    }
    
    Process {
        try {
            # Ensure report directory exists
            $reportDir = Split-Path $ReportPath -Parent
            if ($reportDir -and -not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # Calculate duration string
            $durationString = "N/A"
            if ($BackupInfo.Duration) {
                if ($BackupInfo.Duration -is [TimeSpan]) {
                    $durationString = $BackupInfo.Duration.ToString()
                } else {
                    $durationString = $BackupInfo.Duration.ToString()
                }
            }
            
            # Build Statistics and conditional Changes so incremental-only fields
            # are omitted for Full backups.
            $statisticsHash = @{ 
                FilesBackedUp = $BackupInfo.FilesBackedUp
                TotalSizeMB = $BackupInfo.TotalSizeMB
                Compressed = $BackupInfo.Compressed
                CompressedSizeMB = $BackupInfo.CompressedSizeMB
                CompressionRatio = $BackupInfo.CompressionRatio
            }

            if ($BackupInfo.Type -and $BackupInfo.Type -eq 'Incremental') {
                $statisticsHash.FilesChanged = if ($BackupInfo.FilesChanged) { $BackupInfo.FilesChanged } else { 0 }
                $statisticsHash.FilesNew = if ($BackupInfo.FilesNew) { $BackupInfo.FilesNew } else { 0 }
                $statisticsHash.FilesDeleted = if ($BackupInfo.FilesDeleted) { $BackupInfo.FilesDeleted } else { 0 }
            }

            $reportHash = @{ 
                ReportMetadata = [PSCustomObject]@{
                    GeneratedAt = Get-Date -Format "o"
                    ReportVersion = "1.0"
                    Generator = "FileGuardian"
                }
                BackupDetails = [PSCustomObject]@{
                    BackupName = $BackupInfo.BackupName
                    Type = $BackupInfo.Type
                    Timestamp = $BackupInfo.Timestamp
                    Duration = $durationString
                    Success = $true
                }
                Paths = [PSCustomObject]@{
                    SourcePath = $BackupInfo.SourcePath
                    DestinationPath = $BackupInfo.DestinationPath
                }
                Statistics = [PSCustomObject]$statisticsHash
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

            # Add Changes only for incrementals (omit entirely for full backups)
            if ($BackupInfo.Type -and $BackupInfo.Type -eq 'Incremental') {
                $reportHash.Changes = [PSCustomObject]@{
                    DeletedFiles = if ($BackupInfo.DeletedFiles) { $BackupInfo.DeletedFiles } else { @() }
                }
            }

            $report = [PSCustomObject]$reportHash
            
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