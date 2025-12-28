function Read-Config {
    <#
    .SYNOPSIS
        Reads and parses the backup configuration file.
    
    .DESCRIPTION
        Loads the JSON configuration file and returns a PowerShell object
        containing all backup settings.
    
    .PARAMETER ConfigPath
        Path to the configuration JSON file. Defaults to config/backup-config.json
    
    .EXAMPLE
        $config = Read-Config
        $config = Read-Config -ConfigPath "C:\custom\config.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = "$PSScriptRoot\..\..\..\config\backup-config.json"
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found at: $ConfigPath"
        }
        
        Write-Log -Message "Reading configuration from: $ConfigPath" -Level Info
        $configContent = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
        
        if ([string]::IsNullOrWhiteSpace($configContent)) {
            throw "Configuration file is empty: $ConfigPath"
        }
        
        $config = $configContent | ConvertFrom-Json -ErrorAction Stop
        
        Write-Log -Message "Configuration loaded successfully" -Level Info
        return $config
    }
    catch {
        Write-Error "Failed to read configuration: $_"
        throw
    }
}