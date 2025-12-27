@{
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'f9e8d7c6-b5a4-9382-a1b2-c3d4e5f67891'
    
    # Author of this module
    Author = 'Youmni Malha'
    
    # Company or vendor of this module
    CompanyName = 'FileGuardian'
    
    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Schedule management module for FileGuardian. Handles Windows Task Scheduler integration for automatic backups.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Root module not required when using NestedModules
    
    # Nested modules to load
    NestedModules = @(
        'Register-BackupSchedule.psm1'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Register-BackupSchedule'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            Tags = @('Schedule', 'TaskScheduler', 'Automation', 'FileGuardian', 'Backup')
            ProjectUri = ''
            ReleaseNotes = 'Initial release with Windows Task Scheduler integration'
        }
    }
}