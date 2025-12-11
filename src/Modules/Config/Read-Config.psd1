@{
    # Script module or binary module file associated with this manifest
    RootModule = 'Read-Config.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author of this module
    Author = 'FileGuardian'
    
    # Company or vendor of this module
    CompanyName = 'Youmni Malha'
    
    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Configuration management module for FileGuardian backup system. Reads and validates JSON configuration files.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = @('Read-Config')
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Backup', 'Configuration', 'FileGuardian')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Initial release of configuration reader module.'
        }
    }
}
