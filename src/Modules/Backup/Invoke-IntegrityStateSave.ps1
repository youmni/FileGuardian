function Invoke-IntegrityStateSave {
    <#
    .SYNOPSIS
        Saves the integrity state for a backup.
    
    .DESCRIPTION
        Helper function that saves the integrity state after a backup operation.
        Handles module import and error handling.
    
    .PARAMETER SourcePath
        The source path that was backed up.
    
    .PARAMETER DestinationPath
        The backup destination path.
    
    .PARAMETER BackupName
        Name of the backup for the state file.
    
    .PARAMETER Compress
        Whether the backup was compressed.
    
    .OUTPUTS
        Boolean indicating success or failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupName,
        
        [Parameter()]
        [bool]$Compress
    )
    
    try {
        Write-Log -Message "Saving integrity state..." -Level Info
        $integrityModule = Join-Path $PSScriptRoot "..\Integrity\Save-IntegrityState.ps1"
        
        if (Test-Path $integrityModule) {
            Import-Module $integrityModule -Force
            $stateDir = Join-Path $DestinationPath "states"
            
            # Determine backup name for state file
            $stateBackupName = if ($Compress) {
                (Get-Item $BackupName).BaseName
            } else {
                Split-Path $BackupName -Leaf
            }
            
            Save-IntegrityState -SourcePath $SourcePath -StateDirectory $stateDir -BackupName $stateBackupName
            return $true
        }
        else {
            Write-Warning "Save-IntegrityState module not found. Integrity state not saved."
            return $false
        }
    }
    catch {
        Write-Warning "Failed to save integrity state: $_"
        return $false
    }
}