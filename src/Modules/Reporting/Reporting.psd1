@{
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    
    # Author of this module
    Author = 'Youmni Malha'
    
    # Company or vendor of this module
    CompanyName = 'FileGuardian'
    
    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Reporting module for FileGuardian backup system. Generates and signs backup reports.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Nested modules to load
    NestedModules = @(
        'Write-JsonReport.psm1',
        'Write-HtmlReport.psm1',
        'Protect-Report.psm1',
        'Confirm-ReportSignature.psm1'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Write-JsonReport',
        'Write-HtmlReport',
        'Protect-Report',
        'Confirm-ReportSignature'
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
            Tags = @('Backup', 'Reporting', 'FileGuardian', 'JSON', 'HTML')
            ProjectUri = ''
            ReleaseNotes = 'Initial release with JSON reporting and signature support'
        }
    }
}