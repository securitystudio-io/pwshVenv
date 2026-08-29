function Select-Pwshvenv {
    <#
    .SYNOPSIS
        Displays an interactive, searchable list of available pwshVenv virtual environments.
    .DESCRIPTION
        Retrieves all virtual environment profiles from <VenvRoot> and displays an interactive
        terminal menu with live fuzzy/substring search and keyboard navigation (arrow keys,
        type to filter, Enter to select, Escape to cancel).

        When a profile is selected, Select-Pwshvenv activates it via Enter-Pwshvenv by default.
        Passing -PassThru outputs the selected profile object.
    .PARAMETER VenvRoot
        Directory containing profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .PARAMETER PassThru
        Returns the selected profile object to the pipeline.
    .PARAMETER SkipPythonActivation
        When specified, skips Activate.ps1 during activation.
    .PARAMETER SkipPowershellInit
        When specified, skips environment variables, SetLocation, and post-activate scripts during activation.
    .EXAMPLE
        Select-Pwshvenv
        Displays an interactive terminal menu of all venvs with keyboard search and activates the chosen one.
    .EXAMPLE
        Select-Pwshvenv -PassThru
        Displays the searchable terminal menu, activates the chosen venv, and outputs the selected profile object.
    .LINK
        Get-Pwshvenv
        Enter-Pwshvenv
        New-Pwshvenv
    #>
    [CmdletBinding()]
    param(
        [string] $VenvRoot,

        [switch] $PassThru,

        [switch] $SkipPythonActivation,

        [switch] $SkipPowershellInit
    )

    $root = Resolve-VenvRoot -VenvRoot $VenvRoot
    $profiles = @(Get-Pwshvenv -VenvRoot $root)

    if ($profiles.Count -eq 0) {
        Write-Warning "No pwshVenv profiles found in '$root'."
        return
    }

    $selected = Invoke-VenvTerminalSelector -Profiles $profiles

    if (-not $selected) {
        Write-Verbose 'No profile selected or selection cancelled.'
        return
    }

    $enterParams = @{
        Name     = $selected.Name
        VenvRoot = $root
    }
    if ($SkipPythonActivation) { $enterParams['SkipPythonActivation'] = $true }
    if ($SkipPowershellInit)   { $enterParams['SkipPowershellInit']   = $true }

    Enter-Pwshvenv @enterParams

    if ($PassThru) {
        return $selected
    }
}
