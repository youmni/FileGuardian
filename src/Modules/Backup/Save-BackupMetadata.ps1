function Save-BackupMetadata {
    <#
    .SYNOPSIS
        Saves backup metadata to a JSON file.
    
    .DESCRIPTION
        Helper function that saves backup metadata for integrity verification.
        Metadata includes backup type, source path, timestamp, and file count.
    
    .PARAMETER BackupType
        Type of backup (Full or Incremental).
    
    .PARAMETER SourcePath
        The source path that was backed up.
    
    .PARAMETER Timestamp
        The timestamp of the backup.
    
    .PARAMETER FilesBackedUp
        Number of files backed up.
    
    .PARAMETER TargetPath
        Where to save the metadata file.
    
    .PARAMETER BaseBackup
        For incremental/differential backups, the timestamp of the base backup.
    
    .OUTPUTS
        Boolean indicating success or failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Full", "Incremental", "Differential")]
        [string]$BackupType,
        
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Timestamp,
        
        [Parameter(Mandatory = $true)]
        [int]$FilesBackedUp,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        
        [Parameter()]
        [string]$BaseBackup
        ,
        [Parameter()]
        [string[]]$DeletedFiles
    )
    
    try {
        $metadata = @{
            BackupType = $BackupType
            SourcePath = (Resolve-Path $SourcePath).Path
            Timestamp = $Timestamp
            FilesBackedUp = $FilesBackedUp
        }
        
        if ($BaseBackup) {
            $metadata['BaseBackup'] = $BaseBackup
        }

        if ($DeletedFiles -and $DeletedFiles.Count -gt 0) {
            $metadata['DeletedFiles'] = $DeletedFiles
            $metadata['DeletedCount'] = $DeletedFiles.Count
        }
        
        $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $TargetPath -Encoding UTF8
        Write-Log -Message "Backup metadata saved: $TargetPath" -Level Info
        return $true
    }
    catch {
        Write-Warning "Failed to save backup metadata: $_"
        return $false
    }
}
