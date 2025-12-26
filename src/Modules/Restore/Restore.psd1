@{
    GUID = 'b3a6d2a0-6f4b-4d9f-9f2b-1a2b3c4d5e6f'
    Author = 'FileGuardian'
    CompanyName = 'FileGuardian'
    Copyright = '(c) 2025 FileGuardian'
    ModuleVersion = '1.0.0'
    RootModule = ''
    NestedModules = @(
        'Convert-BackupTimestampToDateTime.psm1',
        'Get-MetadataFromFolder.psm1',
        'Get-MetadataFromZip.psm1',
        'Get-BackupCandidates.psm1'
    )
    FunctionsToExport = @('*')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    FileList = @(
        'Resolve-Backups.psm1',
        'Convert-BackupTimestampToDateTime.psm1',
        'Get-MetadataFromFolder.psm1',
        'Get-MetadataFromZip.psm1',
        'Get-BackupCandidates.psm1'
    )
}