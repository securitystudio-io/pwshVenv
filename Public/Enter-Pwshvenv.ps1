# Module-scoped state used by Exit-Pwshvenv to restore the session.
$script:PwshvenvSnapshot        = $null   # hashtable of env-var values before activation
$script:PwshvenvActive          = $false  # true while a session is active
$script:PwshvenvPythonActivated = $false  # true when Activate.ps1 was dot-sourced

function Enter-Pwshvenv {
    <#
    .SYNOPSIS
        Activates a named Python virtual environment in the current PowerShell session.
    .DESCRIPTION
        Loads the named profile from <VenvRoot>\<Name>.json, then performs up to three steps
        depending on the profile's skip flags and any switch overrides:

          1. Python activation  — dot-sources the venv's Activate.ps1 (skipped when
             SkipPythonActivation is true in the profile or -SkipPythonActivation is passed).
          2. Environment variables — applies key-value pairs from the profile to the current
             process environment (skipped when SkipPowershellInit is true or
             -SkipPowershellInit is passed).
          3. Post-activate scripts — dot-sources each script listed in PostActivateScripts
             (also skipped when SkipPowershellInit is in effect).

        Before applying profile environment variables a snapshot of their current values is
        saved so that Exit-Pwshvenv can restore the original state.

        Only one venv can be active at a time per session. Calling Enter-Pwshvenv while
        another is active emits a warning and returns without switching.
    .PARAMETER Name
        The name of the profile (and virtual environment) to activate. Required.
    .PARAMETER VenvRoot
        Directory containing profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .PARAMETER SkipPythonActivation
        When specified, Activate.ps1 is NOT dot-sourced. Overrides the profile setting.
    .PARAMETER SkipPowershellInit
        When specified, environment variables and post-activate scripts are NOT applied.
        Overrides the profile setting.
    .EXAMPLE
        Enter-Pwshvenv -Name myapp
        Activates the 'myapp' virtual environment with all steps from the profile.
    .EXAMPLE
        Enter-Pwshvenv -Name myapp -SkipPowershellInit
        Activates only the Python venv, skipping env vars and post-activate scripts.
    .EXAMPLE
        Enter-Pwshvenv -Name myapp -SkipPythonActivation
        Applies env vars and post-activate scripts without activating the Python venv.
    .NOTES
        Use Exit-Pwshvenv to deactivate the environment and restore the previous session state.
    .LINK
        Exit-Pwshvenv
        New-Pwshvenv
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [string] $VenvRoot,

        [switch] $SkipPythonActivation,

        [switch] $SkipPowershellInit
    )

    if ($script:PwshvenvActive) {
        Write-Warning "A pwshVenv environment is already active. Run Exit-Pwshvenv first."
        return
    }

    $root        = Resolve-VenvRoot -VenvRoot $VenvRoot
    $venvProfile = Get-VenvProfile -Name $Name -VenvRoot $root

    # Resolve effective skip flags: explicit switch wins over profile value.
    $doPythonActivation = -not ($SkipPythonActivation.IsPresent -or $venvProfile.SkipPythonActivation)
    $doPowershellInit   = -not ($SkipPowershellInit.IsPresent   -or $venvProfile.SkipPowershellInit)

    if ($doPythonActivation) {
        $activateScript = Join-Path $venvProfile.VenvLocation 'Scripts' 'Activate.ps1'
        if (-not (Test-Path -LiteralPath $activateScript -PathType Leaf)) {
            throw "Activate.ps1 not found at '$activateScript'. Has the venv been created? Run New-Pwshvenv first."
        }
        Write-Verbose "Activating: $activateScript"
        . $activateScript
        $script:PwshvenvPythonActivated = $true
    } else {
        Write-Verbose 'Skipping Python activation (SkipPythonActivation is set).'
        $script:PwshvenvPythonActivated = $false
    }

    if ($doPowershellInit) {
        # Snapshot current env-var values before overwriting them.
        $snapshot = @{}
        if ($venvProfile.EnvironmentVariables) {
            foreach ($key in $venvProfile.EnvironmentVariables.PSObject.Properties.Name) {
                $snapshot[$key] = [System.Environment]::GetEnvironmentVariable($key)
            }
        }
        $script:PwshvenvSnapshot = $snapshot

        if ($venvProfile.EnvironmentVariables) {
            foreach ($prop in $venvProfile.EnvironmentVariables.PSObject.Properties) {
                Write-Verbose "Setting env var: $($prop.Name)=$($prop.Value)"
                [System.Environment]::SetEnvironmentVariable($prop.Name, $prop.Value, 'Process')
            }
        }

        Invoke-PostActivateScripts -Scripts $venvProfile.PostActivateScripts
    } else {
        Write-Verbose 'Skipping PowerShell init (SkipPowershellInit is set).'
        $script:PwshvenvSnapshot = @{}
    }

    $script:PwshvenvActive = $true
}
