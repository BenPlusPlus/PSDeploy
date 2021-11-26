<#
.Synopsis
    Delete any files/folders from the destination folder that do not exist in the source.

.Parameter Path
    String. Source path. You can use relative paths.

.Parameter Destination
    String. Destination path. You can use relative paths.

.Example
    Remove-UnmatchedItems -Path 'c:\source' -Destination 'c:\destination'

    Delete any files or folders found in the destination folder that do not exist in the source.
#>
function Remove-UnmatchedItems
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [string]$Destination
    )

    $resolvedSource = Resolve-Path -Path $Path
    $resolvedDest = Resolve-Path -Path $Destination
    $itemsToRemove = @()

    Get-ChildItem $resolvedDest | ForEach-Object {

        $sourceFullName = Join-Path $resolvedSource -ChildPath $_.Name
        if (-not (Test-Path $sourceFullName)) {
            $itemsToRemove += $_.FullName
        }
        elseif ($_.PSIsContainer) {
            # If it's a container that isn't being removed, we'd better recurse into it
            # and remove anything within that doesn't match the source.
            Remove-UnmatchedItems -Path $sourceFullName -Destination $_.FullName
        }
    }

    foreach ($item in $itemsToRemove) {
        Remove-Item -Path $item -Recurse -Force
    }

}

