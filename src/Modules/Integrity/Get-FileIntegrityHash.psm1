function Get-FileIntegrityHash {
    <#
    .SYNOPSIS
        Calculates hash for a file or all files in a directory.
    
    .DESCRIPTION
        Generates SHA256 hashes for files to track integrity.
        Can process single files or entire directory trees.
    
    .PARAMETER Path
        Path to file or directory to hash.
    
    .PARAMETER Algorithm
        Hash algorithm to use. Default is SHA256.
    
    .PARAMETER Recurse
        Process directories recursively.
    
    .EXAMPLE
        Get-FileIntegrityHash -Path "C:\Data"
        Get hashes for all files in C:\Data
    
    .EXAMPLE
        Get-FileIntegrityHash -Path "C:\Data" -Recurse
        Get hashes for all files in C:\Data and subdirectories
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter()]
        [ValidateSet('SHA256', 'SHA1', 'MD5')]
        [string]$Algorithm = 'SHA256',
        
        [Parameter()]
        [switch]$Recurse
    )
    
    Begin {
        Write-Log -Message "Starting hash calculation for: $Path (Algorithm: $Algorithm)" -Level Info
    }
    
    Process {
        try {
            $item = Get-Item -Path $Path -ErrorAction Stop
            
            if ($item.PSIsContainer) {
                # Directory - get all files
                $files = if ($Recurse) {
                    Get-ChildItem -Path $Path -File -Recurse -ErrorAction Stop
                } else {
                    Get-ChildItem -Path $Path -File -ErrorAction Stop
                }
                
                $results = @()
                foreach ($file in $files) {
                    Write-Verbose "Hashing file: $($file.FullName)"
                    $hash = Get-FileHash -Path $file.FullName -Algorithm $Algorithm -ErrorAction Stop
                    
                    # Calculate relative path properly
                    $relPath = $file.FullName.Substring($item.FullName.Length).TrimStart('\')
                    
                    $results += [PSCustomObject]@{
                        Path = $file.FullName
                        RelativePath = $relPath
                        Hash = $hash.Hash
                        Algorithm = $Algorithm
                        Size = $file.Length
                        LastWriteTime = $file.LastWriteTime
                    }
                }
                
                return $results
            }
            else {
                # Single file
                Write-Verbose "Hashing file: $($item.FullName)"
                $hash = Get-FileHash -Path $item.FullName -Algorithm $Algorithm -ErrorAction Stop
                
                return [PSCustomObject]@{
                    Path = $item.FullName
                    RelativePath = $item.Name
                    Hash = $hash.Hash
                    Algorithm = $Algorithm
                    Size = $item.Length
                    LastWriteTime = $item.LastWriteTime
                }
            }
        }
        catch {
            Write-Error "Failed to calculate hash: $_"
            throw
        }
    }
    
    End {
        # Completion already logged in Process block
    }
}