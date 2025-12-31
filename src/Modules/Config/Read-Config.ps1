function Read-Config {
    <#
    .SYNOPSIS
        Reads and parses the backup configuration file.
    
    .DESCRIPTION
        Loads the JSON configuration file and returns a PowerShell object
        containing all backup settings. Caches the result to avoid repeated
        file reads and logging.
    
    .PARAMETER ConfigPath
        Absolute path to the configuration JSON file. No relative paths are used.
        If omitted, the environment variable `FILEGUARDIAN_CONFIG_PATH` must
        be set to the absolute path of the config file.
    
    .PARAMETER Force
        Force reload of configuration, bypassing cache.
    
    .EXAMPLE
        $config = Read-Config
        $config = Read-Config -ConfigPath "C:\custom\config.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = $null,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        # Determine the actual config path
        $actualPath = if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
            if ([string]::IsNullOrWhiteSpace($env:FILEGUARDIAN_CONFIG_PATH)) {
                throw "No configuration path provided. Specify -ConfigPath with an absolute path or set FILEGUARDIAN_CONFIG_PATH to the absolute path of the config file."
            }
            $env:FILEGUARDIAN_CONFIG_PATH
        } else {
            $ConfigPath
        }

        # Resolve to absolute path
        $resolved = Resolve-Path -LiteralPath $actualPath -ErrorAction SilentlyContinue
        if ($resolved) { $actualPath = $resolved.ProviderPath }

        if (-not (Get-Variable -Scope Script -Name FileGuardian_ConfigCache -ErrorAction SilentlyContinue)) {
            $script:FileGuardian_ConfigCache = @{}
        }

        if (-not $Force -and $script:FileGuardian_ConfigCache.ContainsKey($actualPath)) {
            return $script:FileGuardian_ConfigCache[$actualPath]
        }

        if (-not (Test-Path $actualPath)) {
            throw "Configuration file not found at: $actualPath"
        }

        $item = Get-Item -LiteralPath $actualPath
        if ($item.PSIsContainer) {
            throw "Provided FILEGUARDIAN_CONFIG_PATH or -ConfigPath is a directory. Provide the absolute path to the config file."
        }

        Write-Log -Message "Reading configuration from: $actualPath" -Level Info
        $configContent = Get-Content -Path $actualPath -Raw -ErrorAction Stop
        
        if ([string]::IsNullOrWhiteSpace($configContent)) {
            throw "Configuration file is empty: $actualPath"
        }
        
        $config = $configContent | ConvertFrom-Json -ErrorAction Stop
        
        Write-Log -Message "Configuration loaded successfully" -Level Info
        
        $script:FileGuardian_ConfigCache[$actualPath] = $config
        
        return $config
    }
    catch {
        Write-Log -Message "Failed to read configuration: $_" -Level Warning
        Write-Warning "Error reading configuration file: $_"
        throw
    }
}