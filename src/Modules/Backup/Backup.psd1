@{
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'd4e5f6a7-b8c9-0123-def1-234567890123'
    
    # Author of this module
    Author = 'FileGuardian'
    
    # Company or vendor of this module
    CompanyName = 'Youmni Malha'
    
    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Complete backup module suite for FileGuardian. Includes full, incremental, and differential backup types with compression support.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Nested modules to load (all modules, including internal helpers)
    NestedModules = @(
        'Compress-Backup.psm1',
        'Initialize-BackupConfiguration.psm1',
        'Invoke-DifferentialBackup.psm1',
        'Invoke-FullBackup.psm1',
        'Invoke-IncrementalBackup.psm1',
        'Invoke-IntegrityStateSave.psm1',
        'New-BackupReport.psm1',
        'Save-BackupMetadata.psm1',
        'Test-PreviousBackups.psm1'
    )
    
    # Functions to export from this module (only public-facing functions)
    FunctionsToExport = @(
        'Invoke-FullBackup',
        'Invoke-IncrementalBackup',
        'Invoke-DifferentialBackup'
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
            Tags = @('Backup', 'FileGuardian', 'Full-Backup', 'Incremental-Backup', 'Differential-Backup', 'Compression')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'v1.0.0 - Initial release with full backup and compression support.'
        }
    }
}