@{
    # Module manifest for Logging module
    ModuleVersion = '1.0.0'
    
    # Unique ID for this module
    GUID = 'a1b2c3d4-e5f6-4789-a1b2-c3d4e5f67890'
    
    # Author of this module
    Author = 'FileGuardian Team'
    
    # Company or vendor of this module
    CompanyName = 'FileGuardian'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 FileGuardian. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Provides logging functionality for FileGuardian backup operations. Supports console output with color-coded severity levels and optional file logging for audit trails.'
    
    # Minimum version of PowerShell required
    PowerShellVersion = '5.1'
    
    # Root module file
    RootModule = 'Write-Log.psm1'
    
    # Functions to export from this module
    FunctionsToExport = @('Write-Log')
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Logging', 'Backup', 'FileGuardian', 'Audit')
            
            # Release notes
            ReleaseNotes = @'
## Version 1.0.0
- Initial release
- Write-Log function with color-coded console output
- Optional file logging support
- Four severity levels: Info, Warning, Error, Success
'@
        }
    }
}
