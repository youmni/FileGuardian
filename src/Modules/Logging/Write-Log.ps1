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
    
    # Set log path (try config first, then default)
    $dateStamp = Get-Date -Format "yyyyMMdd"
    $logDir = $null
    
    # Try to load config for LogDirectory
    $configPath = Join-Path $PSScriptRoot "..\..\..\config\backup-config.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($config.GlobalSettings.LogDirectory) {
                $logDir = $config.GlobalSettings.LogDirectory
            }
        }
        catch {
            # Fall back to default if config can't be read
            Write-Verbose "Could not load LogDirectory from config: $_"
        }
    }
    
    # Default to relative logs directory if no config
    if (-not $logDir) {
        $logDir = Join-Path $PSScriptRoot "..\..\..\logs"
    }
    
    $logPath = Join-Path $logDir "fileguardian_$dateStamp.log"
    
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