<#
.Synopsis
    Specialized copy function for folder operations required by PSDeploy.

.Parameter Path
    String. Source path. You can use relative path.

.Parameter Destination
    Array of destination paths. You can use relative paths.

.Parameter Purge
    Delete dest files/dirs that no longer exist in source.

.Parameter ExcludeOlder
    Exclude older files if a newer version exists at the destination.

.Example
    'c:\alpha' | Copy-Folder -Destination 'c:\bravo', 'c:\charlie' -Purge

    Copy 'c:\alpha' to 'c:\bravo' and 'c:\charlie'. Delete any items found in the destination folder(s) that do not exist in the source.
#>
function Copy-Folder
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [string[]]$Destination,

        [switch]$Purge,

        [switch]$ExcludeOlder
    )

    Process
    {
        # Requires options to accommodate the following switches in Robocopy:
        # /E :: copy subdirectories, including Empty ones. (We'll just include this as always-on behavior since PSDeploy always passed it as an argument in practice.)
        # /PURGE :: delete dest files/dirs that no longer exist in source.
        # /XO :: eXclude Older files.

        $resolvedPath = Resolve-Path -Path $Path

        foreach ($dest in $Destination) {
            $resolvedDest = Resolve-Path $dest
            if ($Purge) {
                Write-Verbose "Purging non-matching files/folders from target folder: $resolvedDest"
                Remove-UnmatchedItems -Path $resolvedPath -Destination $resolvedDest
            }

            $itemsToCopy = @()

            Get-ChildItem $resolvedPath -Recurse | ForEach-Object {
                # We use the resolved paths here because we need to identify any specific subfolders
                # that need to be accounted for (tested and created) under $dest for Copy-Item to work.
                $partialPath = $_.FullName.Replace($resolvedPath, [string]::Empty)
                if ($partialPath.EndsWith('\') -or $partialPath.EndsWith('/')) {
                    $partialPath = $partialPath.Substring(0, $partialPath.Length - 1)
                }
                $destFullName = Join-Path $resolvedDest -ChildPath $partialPath
                
                if ($_.PSIsContainer) {
                    if (-not (Test-Path $destFullName -PathType Container)) {
                        Write-Verbose "Creating folder: $destFullName"
                        New-Item -Path $destFullName -ItemType Directory | Out-Null
                    }
                }
                else {
                    if ($ExcludeOlder -and (Test-Path -Path $destFullName)) {
                        $destItem = Get-Item $destFullName
                        if ($_.CreationTime -gt $destItem.CreationTime) {
                            $itemsToCopy += @{Source=$_.FullName;Destination=$destFullName}
                        }
                    }
                    else {
                        $itemsToCopy += @{Source=$_.FullName;Destination=$destFullName}
                    }
                }
            }

            Write-Verbose "Files to copy: $($itemsToCopy.Count)"
            foreach ($item in $itemsToCopy) {
                Write-Verbose "Copying file to: $($item.Destination)"
                Copy-Item -Path $item.Source -Destination $item.Destination -Force
            }
        }
    }

}

