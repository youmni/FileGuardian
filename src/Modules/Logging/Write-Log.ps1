function Write-Log {
    <#
    .SYNOPSIS
        Internal logging function for FileGuardian operations.
    .DESCRIPTION
        This function is for internal use only by FileGuardian modules.
        Writes log messages to console and automatically to daily log file.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The log level (Info, Warning, Error, Success). Default: Info
    .NOTES
        Internal use only - not intended for direct user invocation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    $dateStamp = Get-Date -Format "yyyyMMdd"
    if (-not (Get-Variable -Scope Script -Name FileGuardian_LogDir -ErrorAction SilentlyContinue)) {
        $script:FileGuardian_LogDir = $null
    }

    if (-not $script:FileGuardian_LogDir) {
        if ($env:FILEGUARDIAN_LOG_DIRECTORY) {
            $script:FileGuardian_LogDir = $env:FILEGUARDIAN_LOG_DIRECTORY
        }
        elseif ($env:ProgramData) {
            $script:FileGuardian_LogDir = Join-Path $env:ProgramData "FileGuardian\logs"
        }
        else {
            $script:FileGuardian_LogDir = Join-Path $env:LOCALAPPDATA "FileGuardian\logs"
        }
    }

    $logDir = $script:FileGuardian_LogDir
    $logPath = Join-Path $logDir "fileguardian_$dateStamp.log"
    
    # Log rotation: remove old log files older than retention period
    $logRetentionDays = 90

    try {
        if (Test-Path $logDir) {
            Get-ChildItem -Path $logDir -File -Filter "fileguardian_*.log" |
                Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$logRetentionDays) } |
                ForEach-Object {
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                    Write-Verbose "Removed old log file: $($_.Name)"
                }
        }
    }
    catch {
        Write-Verbose "Log rotation failed: $_"
    }
    # Console output with colors
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Cyan }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
    }
    
    # Write to log file
    try {
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        # Use Out-File with -Append to ensure proper newlines
        $logMessage | Out-File -FilePath $logPath -Append -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}