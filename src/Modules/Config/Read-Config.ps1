function Read-Config {
    <#
    .SYNOPSIS
        Reads and parses the backup configuration file.
    
    .DESCRIPTION
        Loads the JSON configuration file and returns a PowerShell object
        containing all backup settings.
    
    .PARAMETER ConfigPath
        Absolute path to the configuration JSON file. No relative paths are used.
        If omitted, the environment variable `FILEGUARDIAN_CONFIG_PATH` must
        be set to the absolute path of the config file.
    
    .EXAMPLE
        $config = Read-Config
        $config = Read-Config -ConfigPath "C:\custom\config.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = $null
    )
    
    try {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
            if ([string]::IsNullOrWhiteSpace($env:FILEGUARDIAN_CONFIG_PATH)) {
                throw "No configuration path provided. Specify -ConfigPath with an absolute path or set FILEGUARDIAN_CONFIG_PATH to the absolute path of the config file."
            }

            $ConfigPath = $env:FILEGUARDIAN_CONFIG_PATH
        }

        # Require that provided paths are files and exist.
        $resolved = Resolve-Path -LiteralPath $ConfigPath -ErrorAction SilentlyContinue
        if ($resolved) { $ConfigPath = $resolved.ProviderPath }

        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found at: $ConfigPath"
        }

        $item = Get-Item -LiteralPath $ConfigPath
        if ($item.PSIsContainer) {
            throw "Provided FILEGUARDIAN_CONFIG_PATH or -ConfigPath is a directory. Provide the absolute path to the config file."
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
        Write-Log -Message "Failed to read configuration: $_" -Level Warning
        Write-Warning "Error reading configuration file: $_"
        throw
    }
}