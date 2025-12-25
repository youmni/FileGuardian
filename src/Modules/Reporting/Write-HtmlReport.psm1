function Write-HtmlReport {
    <#
    .SYNOPSIS
        Generates an HTML backup report.
    
    .DESCRIPTION
        Creates a detailed HTML report containing backup metadata, statistics,
        and integrity information with a professional, user-friendly layout.
    
    .PARAMETER BackupInfo
        Hashtable or PSCustomObject containing backup information.
    
    .PARAMETER ReportPath
        Path where the report will be saved. If not specified, saves to reports folder.
    
    .EXAMPLE
        Write-HtmlReport -BackupInfo $backupResult -ReportPath ".\reports\backup_report.html"
        Generates an HTML report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$BackupInfo,
        
        [Parameter()]
        [string]$ReportPath
    )
    
    Begin {
        Write-Log -Message "Generating HTML backup report..." -Level Info
        
        # If no report path specified, create one
        if (-not $ReportPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $reportDir = ".\reports"
            
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            $backupName = if ($BackupInfo.BackupName) { $BackupInfo.BackupName } else { "backup" }
            $ReportPath = Join-Path $reportDir "${backupName}_${timestamp}_report.html"
        }
        # If ReportPath is a directory or has no extension (assume directory), generate filename
        elseif ((Test-Path $ReportPath -PathType Container) -or (-not [System.IO.Path]::HasExtension($ReportPath))) {
            # Create directory if it doesn't exist
            if (-not (Test-Path $ReportPath)) {
                New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
            }
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupName = if ($BackupInfo.BackupName) { $BackupInfo.BackupName } else { "backup" }
            $ReportPath = Join-Path $ReportPath "${backupName}_${timestamp}_report.html"
        }
    }
    
    Process {
        try {
            # Ensure report directory exists
            $reportDir = Split-Path $ReportPath -Parent
            if ($reportDir -and -not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # Prepare data for HTML
            $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $duration = if ($BackupInfo.Duration) { $BackupInfo.Duration.ToString() } else { "N/A" }
            $compressed = if ($BackupInfo.Compressed) { "Yes" } else { "No" }
            $compressedSize = if ($BackupInfo.Compressed -and $BackupInfo.CompressedSizeMB) { 
                "$($BackupInfo.CompressedSizeMB) MB" 
            } else { 
                "N/A" 
            }
            $compressionRatio = if ($BackupInfo.CompressionRatio) { 
                "$([Math]::Round($BackupInfo.CompressionRatio, 2))%" 
            } else { 
                "N/A" 
            }
            $stateDir = if ($BackupInfo.DestinationPath) { 
                Join-Path $BackupInfo.DestinationPath "states" 
            } else { 
                "N/A" 
            }
            $integrityState = if ($BackupInfo.IntegrityStateSaved) { 
                "<span class='status-success'>Saved</span>" 
            } else { 
                "<span class='status-error'>Not Saved</span>" 
            }
            
            # Prepare corruption verification info
            $hasCorruption = $BackupInfo.CorruptedBackups -and $BackupInfo.CorruptedBackups.Count -gt 0
            $corruptionHtml = ""
            if ($hasCorruption) {
                $corruptionHtml = "<div class='warning-box'><h3>[!] WARNING: Corrupted Previous Backups Detected</h3>"
                $corruptionHtml += "<p>The following previous backups have integrity issues:</p>"
                foreach ($corrupted in $BackupInfo.CorruptedBackups) {
                    $corruptionHtml += "<div class='corrupted-item'>"
                    $corruptionHtml += "<strong>$($corrupted.BackupName)</strong><br>"
                    $corruptionHtml += "Corrupted Files: $($corrupted.CorruptedFiles) | Missing Files: $($corrupted.MissingFiles) | Total Issues: $($corrupted.TotalIssues)<br>"
                    
                    # Add corrupted files list
                    if ($corrupted.CorruptedFilesList -and $corrupted.CorruptedFilesList.Count -gt 0) {
                        $corruptionHtml += "<div style='margin-top:8px'><em>Corrupted:</em> "
                        $corruptionHtml += ($corrupted.CorruptedFilesList -join ', ')
                        $corruptionHtml += "</div>"
                    }
                    
                    # Add missing files list
                    if ($corrupted.MissingFilesList -and $corrupted.MissingFilesList.Count -gt 0) {
                        $corruptionHtml += "<div style='margin-top:4px'><em>Missing:</em> "
                        $corruptionHtml += ($corrupted.MissingFilesList -join ', ')
                        $corruptionHtml += "</div>"
                    }
                    
                    $corruptionHtml += "</div>"
                }
                $corruptionHtml += "</div>"
            }
            
            $reportVersion = "1.0"
            $generator = "FileGuardian"
            $generatedAtIso = Get-Date -Format "o"

            $filesChanged = if ($BackupInfo.FilesChanged) { $BackupInfo.FilesChanged } else { 0 }
            $filesNew = if ($BackupInfo.FilesNew) { $BackupInfo.FilesNew } else { 0 }
            $filesDeleted = if ($BackupInfo.FilesDeleted) { $BackupInfo.FilesDeleted } else { 0 }

            $deletedFilesHtml = ""
            if ($BackupInfo.DeletedFiles -and $BackupInfo.DeletedFiles.Count -gt 0) {
                $deletedFilesHtml = "<ul style='margin-top:8px'>"
                foreach ($d in $BackupInfo.DeletedFiles) {
                    $deletedFilesHtml += "<li>" + [System.Web.HttpUtility]::HtmlEncode($d) + "</li>"
                }
                $deletedFilesHtml += "</ul>"
            } else {
                $deletedFilesHtml = "<div class='value'>None</div>"
            }

            $totalVerified = if ($BackupInfo.PreviousBackupsVerified) { $BackupInfo.PreviousBackupsVerified } else { 0 }
            $verifiedOK = if ($BackupInfo.VerifiedBackupsOK) { $BackupInfo.VerifiedBackupsOK } else { 0 }
            $corruptedCount = if ($BackupInfo.CorruptedBackups) { $BackupInfo.CorruptedBackups.Count } else { 0 }

            $verificationSummary = if ($totalVerified -gt 0) {
                "$verifiedOK OK, $corruptedCount Corrupted (Total: $totalVerified verified)"
            } else {
                "No previous backups to verify"
            }
            
            # Build HTML content with modern styling
            $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FileGuardian Backup Report - $($BackupInfo.BackupName)</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }
        
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.2);
        }
        
        header .subtitle {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .content {
            padding: 40px;
        }
        
        .section {
            margin-bottom: 30px;
            background: #f8f9fa;
            border-radius: 8px;
            padding: 25px;
            border-left: 4px solid #667eea;
        }
        
        .section h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.8em;
            display: flex;
            align-items: center;
        }
        
        .section h2::before {
            content: '\25A0';
            margin-right: 10px;
            font-size: 1.2em;
            color: #667eea;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
        }
        
        .info-item {
            background: white;
            padding: 15px;
            border-radius: 6px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
        }
        
        .info-item label {
            font-weight: 600;
            color: #555;
            display: block;
            margin-bottom: 5px;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .info-item .value {
            color: #333;
            font-size: 1.1em;
            font-weight: 500;
            word-break: break-all;
        }
        
        .highlight-box {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            margin: 20px 0;
        }
        
        .highlight-box .number {
            font-size: 2.5em;
            font-weight: bold;
            display: block;
            margin-bottom: 5px;
        }
        
        .highlight-box .label {
            font-size: 1em;
            opacity: 0.9;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            transition: transform 0.2s;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        }
        
        .stat-card .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
            display: block;
            margin-bottom: 5px;
        }
        
        .stat-card .stat-label {
            color: #666;
            font-size: 0.9em;
        }
        
        .status-success {
            color: #28a745;
            font-weight: bold;
        }
        
        .status-error {
            color: #dc3545;
            font-weight: bold;
        }
        
        .status-warning {
            color: #ffc107;
            font-weight: bold;
        }
        
        .warning-box {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        
        .warning-box h3 {
            color: #856404;
            margin-bottom: 10px;
        }
        
        .warning-box .corrupted-item {
            background: white;
            padding: 10px;
            margin: 10px 0;
            border-radius: 4px;
            border-left: 3px solid #dc3545;
        }
        
        .warning-box .corrupted-item strong {
            color: #dc3545;
        }
        
        footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #dee2e6;
        }
        
        footer .signature-notice {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            padding: 15px;
            border-radius: 6px;
            margin-top: 15px;
            color: #856404;
        }
        
        footer .signature-notice strong {
            color: #856404;
        }
        
        @media print {
            body {
                background: white;
                padding: 0;
            }
            
            .container {
                box-shadow: none;
            }
            
            .stat-card:hover {
                transform: none;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>FileGuardian</h1>
            <div class="subtitle">Backup Report</div>
        </header>
        
        <div class="content">
            <!-- Backup Details Section -->
            <div class="section">
                <h2>Backup Details</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Backup Name</label>
                        <div class="value">$($BackupInfo.BackupName)</div>
                    </div>
                    <div class="info-item">
                        <label>Type</label>
                        <div class="value">$($BackupInfo.Type)</div>
                    </div>
                    <div class="info-item">
                        <label>Timestamp</label>
                        <div class="value">$($BackupInfo.Timestamp)</div>
                    </div>
                    <div class="info-item">
                        <label>Duration</label>
                        <div class="value">$duration</div>
                    </div>
                    <div class="info-item">
                        <label>Status</label>
                        <div class="value"><span class="status-success">Success</span></div>
                    </div>
                            <div class="info-item">
                                <label>Report Generated (ISO)</label>
                                <div class="value">$generatedAtIso</div>
                            </div>
                            <div class="info-item">
                                <label>Report Version</label>
                                <div class="value">$reportVersion</div>
                            </div>
                            <div class="info-item">
                                <label>Generator</label>
                                <div class="value">$generator</div>
                            </div>
                </div>
            </div>
            
            <!-- Paths Section -->
            <div class="section">
                <h2>Paths</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Source Path</label>
                        <div class="value">$($BackupInfo.SourcePath)</div>
                    </div>
                    <div class="info-item">
                        <label>Destination Path</label>
                        <div class="value">$($BackupInfo.DestinationPath)</div>
                    </div>
                </div>
            </div>
            
            <!-- Statistics Section -->
            <div class="section">
                <h2>Statistics</h2>
                <div class="stats-grid">
                    <div class="stat-card">
                        <span class="stat-number">$($BackupInfo.FilesBackedUp)</span>
                        <span class="stat-label">Files Backed Up</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-number">$($BackupInfo.TotalSizeMB)</span>
                        <span class="stat-label">Total Size (MB)</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-number">$compressed</span>
                        <span class="stat-label">Compressed</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-number">$compressedSize</span>
                        <span class="stat-label">Compressed Size</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-number">$compressionRatio</span>
                        <span class="stat-label">Compression Ratio</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-number">$filesChanged</span>
                        <span class="stat-label">Files Changed</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-number">$filesNew</span>
                        <span class="stat-label">Files New</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-number">$filesDeleted</span>
                        <span class="stat-label">Files Deleted</span>
                    </div>
                </div>
            </div>

            <!-- Changes Section -->
            <div class="section">
                <h2>Changes</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Deleted Files</label>
                        $deletedFilesHtml
                    </div>
                </div>
            </div>
            
            <!-- Integrity Section -->
            <div class="section">
                <h2>Integrity</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Integrity State</label>
                        <div class="value">$integrityState</div>
                    </div>
                    <div class="info-item">
                        <label>State Directory</label>
                        <div class="value">$stateDir</div>
                    </div>
                </div>
            </div>
            
            <!-- Previous Backups Verification Section -->
            <div class="section">
                <h2>Previous Backups Verification</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Verification Summary</label>
                        <div class="value">$verificationSummary</div>
                    </div>
                </div>
                $corruptionHtml
            </div>
            
            <!-- System Info Section -->
            <div class="section">
                <h2>System Information</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Computer Name</label>
                        <div class="value">$env:COMPUTERNAME</div>
                    </div>
                    <div class="info-item">
                        <label>User Name</label>
                        <div class="value">$env:USERNAME</div>
                    </div>
                    <div class="info-item">
                        <label>OS Version</label>
                        <div class="value">$([System.Environment]::OSVersion.VersionString)</div>
                    </div>
                    <div class="info-item">
                        <label>PowerShell Version</label>
                        <div class="value">$($PSVersionTable.PSVersion.ToString())</div>
                    </div>
                </div>
            </div>
        </div>
        
        <footer>
            <p>Report generated at: <strong>$generatedAt</strong></p>
            <p>Generator: FileGuardian</p>
            <div class="signature-notice">
                <strong>Digital Signature</strong><br>
                This report is digitally signed. A .sig file has been created alongside this report for verification.
                The integrity of this report can be verified using the corresponding signature file.
            </div>
        </footer>
    </div>
</body>
</html>
"@
    
            # Save HTML report with UTF8 without BOM to prevent encoding issues
            [System.IO.File]::WriteAllText($ReportPath, $htmlContent, [System.Text.UTF8Encoding]::new($false))
            
            Write-Host "`nBackup report generated:" -ForegroundColor Green
            Write-Host "  Location: $ReportPath" -ForegroundColor Gray
            Write-Host "  Format: HTML" -ForegroundColor Gray
            
            # Return report info
            return [PSCustomObject]@{
                ReportPath = $ReportPath
                Format = "HTML"
                GeneratedAt = Get-Date
                Size = (Get-Item $ReportPath).Length
            }
        }
        catch {
            Write-Error "Failed to generate HTML report: $_"
            throw
        }
    }
}
