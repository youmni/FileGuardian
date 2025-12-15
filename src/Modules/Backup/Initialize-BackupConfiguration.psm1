function Initialize-BackupConfiguration {
    <#
    .SYNOPSIS
        Loads and initializes backup configuration with parameter overrides.
    
    .DESCRIPTION
        Helper function that loads configuration from file and applies parameter overrides.
        Returns a configuration object with all necessary settings for backup operations.
    
    .PARAMETER ConfigPath
        Path to the configuration file.
    
    .PARAMETER DestinationPath
        Override for destination path from config.
    
    .PARAMETER Compress
        Override for compression setting from config.
    
    .PARAMETER ExcludePatterns
        Override for exclusion patterns from config.
    
    .PARAMETER ReportFormat
        Override for report format from config.
    
    .PARAMETER ReportOutputPath
        Override for report output path from config.
    
    .PARAMETER BoundParameters
        The $PSBoundParameters from the calling function.
    
    .OUTPUTS
        PSCustomObject with resolved configuration values.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath,
        
        [Parameter()]
        [string]$DestinationPath,
        
        [Parameter()]
        [bool]$Compress,
        
        [Parameter()]
        [string[]]$ExcludePatterns,
        
        [Parameter()]
        [string]$ReportFormat,
        
        [Parameter()]
        [string]$ReportOutputPath,
        
        [Parameter()]
        [hashtable]$BoundParameters
    )
    
    # Import Read-Config module
    $configModule = Join-Path $PSScriptRoot "..\Config\Read-Config.psm1"
    Import-Module $configModule -Force
    
    # Load configuration
    try {
        $config = if ($ConfigPath) {
            Read-Config -ConfigPath $ConfigPath
        } else {
            Read-Config -ErrorAction SilentlyContinue
        }
        if ($config) {
            Write-Log -Message "Configuration loaded successfully" -Level Info
        }
    }
    catch {
        Write-Log -Message "Could not load config file: $_. Using parameters only." -Level Warning
        $config = $null
    }
    
    # Apply config defaults for destination if not specified
    if (-not $DestinationPath) {
        if ($config -and $config.BackupSettings.DestinationPath) {
            $DestinationPath = $config.BackupSettings.DestinationPath
            Write-Log -Message "Using DestinationPath from config: $DestinationPath" -Level Info
            Write-Verbose "Using DestinationPath from config: $DestinationPath"
        }
        else {
            Write-Log -Message "DestinationPath not specified and not found in config" -Level Error
            throw "DestinationPath is required. Specify it as a parameter or in the config file."
        }
    }
    
    # Use config for compression if not explicitly specified
    if (-not $BoundParameters.ContainsKey('Compress') -and $config -and $config.BackupSettings.CompressBackups) {
        $Compress = $config.BackupSettings.CompressBackups
        Write-Verbose "Using Compress setting from config: $Compress"
    }
    
    # Use config for exclusion patterns if not specified
    if (-not $ExcludePatterns -and $config -and $config.BackupSettings.ExcludePatterns) {
        $ExcludePatterns = $config.BackupSettings.ExcludePatterns
        Write-Verbose "Using ExcludePatterns from config: $($ExcludePatterns -join ', ')"
    }
    
    if (-not $ExcludePatterns) {
        $ExcludePatterns = @()
    }
    
    # Use config for ReportFormat if not explicitly specified
    if (-not $BoundParameters.ContainsKey('ReportFormat') -and $config -and $config.GlobalSettings.ReportFormat) {
        $ReportFormat = $config.GlobalSettings.ReportFormat
        Write-Verbose "Using ReportFormat from config: $ReportFormat"
    }
    
    if (-not $ReportFormat) {
        $ReportFormat = "JSON"
    }
    
    # Use config for ReportOutputPath if not specified
    if (-not $ReportOutputPath -and $config -and $config.GlobalSettings.ReportOutputPath) {
        $ReportOutputPath = $config.GlobalSettings.ReportOutputPath
        Write-Verbose "Using ReportOutputPath from config: $ReportOutputPath"
    }
    
    return [PSCustomObject]@{
        DestinationPath = $DestinationPath
        Compress = $Compress
        ExcludePatterns = $ExcludePatterns
        ReportFormat = $ReportFormat
        ReportOutputPath = $ReportOutputPath
        Config = $config
    }
}
