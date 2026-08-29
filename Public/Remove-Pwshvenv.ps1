function Remove-Pwshvenv {
    <#
    .SYNOPSIS
        Deletes a virtual environment profile and/or its virtual environment directory.
    .DESCRIPTION
        Removes the profile JSON file (<VenvRoot>\<Name>.json) and the virtual environment directory.
        Use -KeepVenv to remove only the profile configuration, or -KeepProfile to remove only
        the virtual environment directory.

        If the virtual environment is currently active in the session, Remove-Pwshvenv requires
        -Force to automatically deactivate and remove it.
    .PARAMETER Name
        The name of the virtual environment to remove.
    .PARAMETER KeepVenv
        Deletes only the profile JSON file, preserving the virtual environment directory on disk.
    .PARAMETER KeepProfile
        Deletes only the virtual environment directory, preserving the profile JSON file.
    .PARAMETER Force
        Forces removal even if the environment is currently active in the session (automatically deactivates it).
    .PARAMETER VenvRoot
        Directory containing profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .EXAMPLE
        Remove-Pwshvenv -Name myapp
        Deletes both the myapp.json profile and the myapp virtual environment directory.
    .EXAMPLE
        Remove-Pwshvenv -Name myapp -KeepVenv
        Deletes only the myapp.json profile, keeping the venv folder on disk.
    .EXAMPLE
        Get-Pwshvenv | Where-Object Name -like 'temp*' | Remove-Pwshvenv
        Removes all profiles matching 'temp*'.
    .LINK
        Get-Pwshvenv
        New-Pwshvenv
        Exit-Pwshvenv
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [switch] $KeepVenv,

        [switch] $KeepProfile,

        [switch] $Force,

        [string] $VenvRoot
    )

    process {
        $root = Resolve-VenvRoot -VenvRoot $VenvRoot
        $profile = Get-VenvProfile -Name $Name -VenvRoot $root

        if ($script:PwshvenvActive) {
            $activeEnv = $env:VIRTUAL_ENV
            $isThisActive = $activeEnv -and ($profile.VenvLocation -and ($activeEnv -replace '[\\/]$', '') -eq ($profile.VenvLocation -replace '[\\/]$', ''))

            if ($isThisActive) {
                if (-not $Force) {
                    throw "Virtual environment '$Name' is currently active in this session. Run Exit-Pwshvenv first or pass -Force."
                } else {
                    Write-Verbose "Deactivating active venv '$Name' before removal."
                    Exit-Pwshvenv
                }
            }
        }

        $deleteVenv = if ($KeepVenv) { $false } else { $true }
        $deleteProfile = if ($KeepProfile) { $false } else { $true }

        if ($deleteVenv -and (Test-Path -LiteralPath $profile.VenvLocation)) {
            if ($PSCmdlet.ShouldProcess($profile.VenvLocation, 'Remove virtual environment directory')) {
                Remove-Item -LiteralPath $profile.VenvLocation -Recurse -Force
                Write-Verbose "Removed venv directory: $($profile.VenvLocation)"
            }
        }

        if ($deleteProfile -and (Test-Path -LiteralPath $profile.ProfilePath -PathType Leaf)) {
            if ($PSCmdlet.ShouldProcess($profile.ProfilePath, 'Remove profile JSON file')) {
                Remove-Item -LiteralPath $profile.ProfilePath -Force
                Write-Verbose "Removed profile JSON: $($profile.ProfilePath)"
            }
        }
    }
}
