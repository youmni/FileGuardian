@{
    RootModule = ''
    ModuleVersion = '1.0.0'
    GUID = '8f3a4c7d-9e2b-4a1f-b6c8-5d9e7a3f2c1b'
    Author = 'Youmni Malha'
    CompanyName = 'FileGuardian'
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'Integrity verification module for FileGuardian backup system'
    PowerShellVersion = '5.1'
    
    NestedModules = @(
        'Get-FileIntegrityHash.psm1',
        'Save-IntegrityState.psm1',
        'Compare-BackupIntegrity.psm1',
        'Test-BackupIntegrity.psm1'
    )
    
    # Functions to export. `Get-FileIntegrityHash` is used by backup modules
    # and must be publicly available. Keep other internal helpers if needed.
    FunctionsToExport = @(
        'Get-FileIntegrityHash',
        'Save-IntegrityState',
        'Compare-BackupIntegrity',
        'Test-BackupIntegrity'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Backup', 'Integrity', 'Hash', 'Verification')
            ProjectUri = ''
            ReleaseNotes = 'Initial release of Integrity module'
        }
    }
}
