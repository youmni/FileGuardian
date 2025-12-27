<#
.SYNOPSIS
    Quick start wrapper for FileGuardian.

.DESCRIPTION
    This script provides a simple entry point for FileGuardian operations.
    It automatically loads the FileGuardian module and passes all parameters
    to the main Invoke-FileGuardian command.

.EXAMPLE
    .\Start-FileGuardian.ps1 -Action Backup -SourcePath "C:\Data"
    
.EXAMPLE
    .\Start-FileGuardian.ps1 -Action Verify -BackupPath ".\backups\MyBackup_20251213_120000"
    
.EXAMPLE
    .\Start-FileGuardian.ps1 -Action Schedule

.EXAMPLE
    .\Start-FileGuardian.ps1 -Action Schedule -BackupName "DailyDocuments"

.EXAMPLE
    .\Start-FileGuardian.ps1 -Action Schedule -Remove

.EXAMPLE
    .\Start-FileGuardian.ps1 -Action Cleanup -BackupName "MyBackup"

.NOTES
    This is a convenience wrapper. You can also import the module directly:
    Import-Module .\src\FileGuardian.psd1
    Invoke-FileGuardian -Action Backup -SourcePath "C:\Data"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('Backup', 'Verify', 'Report', 'Restore', 'Schedule', 'Cleanup')]
    [string]$Action,
    
    [Parameter()]
    [string]$SourcePath,
    
    [Parameter()]
    [string]$DestinationPath,
    
    [Parameter()]
    [ValidateSet('Full', 'Incremental', 'Differential')]
    [string]$BackupType = 'Full',
    
    [Parameter()]
    [string]$BackupPath,
    
    [Parameter()]
    [string]$ReportPath,
    
    [Parameter()]
    [string]$ReportOutputPath,
    
    [Parameter()]
    [string]$BackupName,

    [Parameter()]
    [string]$BackupDirectory,

    [Parameter()]
    [string]$RestoreDirectory,
    
    [Parameter()]
    [string]$CleanupBackupDirectory,
    
    [Parameter()]
    [ValidateSet('JSON', 'HTML', 'CSV')]
    [string]$ReportFormat,
    
    [Parameter()]
    [string]$ConfigPath,
    
    [Parameter()]
    [switch]$Compress,
    
    [Parameter()]
    [string[]]$ExcludePatterns,
    
    [Parameter()]
    [switch]$Remove,
    
    [Parameter()]
    [int]$RetentionDays,
    
    [Parameter()]
    [switch]$Quiet
)

# Get script directory
$scriptDir = $PSScriptRoot

# Import FileGuardian module
$moduleManifest = Join-Path $scriptDir "src\FileGuardian.psd1"

if (-not (Test-Path $moduleManifest)) {
    Write-Error "FileGuardian module not found at: $moduleManifest"
    exit 1
}

try {
    Import-Module $moduleManifest -Force -ErrorAction Stop
    
    # Build parameter hashtable
    $params = @{
        Action = $Action
    }
    
    if ($PSBoundParameters.ContainsKey('SourcePath')) { $params.SourcePath = $SourcePath }
    if ($PSBoundParameters.ContainsKey('DestinationPath')) { $params.DestinationPath = $DestinationPath }
    if ($PSBoundParameters.ContainsKey('BackupType')) { $params.BackupType = $BackupType }
    if ($PSBoundParameters.ContainsKey('BackupPath')) { $params.BackupPath = $BackupPath }
    if ($PSBoundParameters.ContainsKey('ReportPath')) { $params.ReportPath = $ReportPath }
    if ($PSBoundParameters.ContainsKey('ReportOutputPath')) { $params.ReportOutputPath = $ReportOutputPath }
    if ($PSBoundParameters.ContainsKey('BackupName')) { $params.BackupName = $BackupName }
    if ($PSBoundParameters.ContainsKey('BackupDirectory')) { $params.BackupDirectory = $BackupDirectory }
    if ($PSBoundParameters.ContainsKey('RestoreDirectory')) { $params.RestoreDirectory = $RestoreDirectory }
    if ($PSBoundParameters.ContainsKey('CleanupBackupDirectory')) { $params.CleanupBackupDirectory = $CleanupBackupDirectory }
    if ($PSBoundParameters.ContainsKey('ReportFormat')) { $params.ReportFormat = $ReportFormat }
    if ($PSBoundParameters.ContainsKey('ConfigPath')) { $params.ConfigPath = $ConfigPath }
    if ($PSBoundParameters.ContainsKey('Compress')) { $params.Compress = $true }
    if ($PSBoundParameters.ContainsKey('ExcludePatterns')) { $params.ExcludePatterns = $ExcludePatterns }
    if ($PSBoundParameters.ContainsKey('Remove')) { $params.Remove = $true }
    if ($PSBoundParameters.ContainsKey('RetentionDays')) { $params.RetentionDays = $RetentionDays }
    if ($PSBoundParameters.ContainsKey('Quiet')) { $params.Quiet = $true }
    
    # Execute FileGuardian
    $result = Invoke-FileGuardian @params
    
    # Return result
    return $result
}
catch {
    Write-Error "Failed to execute FileGuardian: $_"
    exit 1
}