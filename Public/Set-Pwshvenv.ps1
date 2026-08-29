function Set-Pwshvenv {
    <#
    .SYNOPSIS
        Updates configuration properties of an existing pwshVenv profile.
    .DESCRIPTION
        Modifies one or more fields in <VenvRoot>\<Name>.json. Any parameter passed explicitly
        updates the corresponding profile field. Optional string fields can be cleared using
        -ClearSetLocation or -ClearRequirementsFile.

        Does not recreate or rebuild the virtual environment on disk. To rebuild after modifying
        PythonPath or RequirementsFile, run Update-Pwshvenv.
    .PARAMETER Name
        The name of the virtual environment profile to modify.
    .PARAMETER PythonPath
        The Python interpreter to associate with this profile.
    .PARAMETER RequirementsFile
        Path to a requirements.txt file.
    .PARAMETER VenvLocation
        Custom path where the virtual environment is stored.
    .PARAMETER SetLocation
        Directory to navigate to upon Enter-Pwshvenv.
    .PARAMETER EnvironmentVariables
        Hashtable of environment variables to store in the profile (replaces existing table).
    .PARAMETER PostActivateScripts
        Array of .ps1 scripts to dot-source upon Enter-Pwshvenv (replaces existing list).
    .PARAMETER SkipPythonActivation
        Set to $true or $false in the profile.
    .PARAMETER SkipPowershellInit
        Set to $true or $false in the profile.
    .PARAMETER ClearSetLocation
        Removes the SetLocation configuration from the profile.
    .PARAMETER ClearRequirementsFile
        Removes the RequirementsFile configuration from the profile.
    .PARAMETER PassThru
        Outputs the updated profile object.
    .PARAMETER VenvRoot
        Directory containing profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .EXAMPLE
        Set-Pwshvenv -Name myapp -SetLocation C:\Projects\myapp
        Updates the working directory for 'myapp'.
    .EXAMPLE
        Set-Pwshvenv -Name myapp -ClearRequirementsFile
        Removes the requirements file association from 'myapp'.
    .LINK
        Get-Pwshvenv
        Update-Pwshvenv
        Set-PwshvenvEnvironmentVariable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [string] $PythonPath,

        [string] $RequirementsFile,

        [string] $VenvLocation,

        [string] $SetLocation,

        [hashtable] $EnvironmentVariables,

        [string[]] $PostActivateScripts,

        [Nullable[bool]] $SkipPythonActivation,

        [Nullable[bool]] $SkipPowershellInit,

        [switch] $ClearSetLocation,

        [switch] $ClearRequirementsFile,

        [switch] $PassThru,

        [string] $VenvRoot
    )

    process {
        $root = Resolve-VenvRoot -VenvRoot $VenvRoot
        $profile = Get-VenvProfile -Name $Name -VenvRoot $root

        $envVars = @{}
        if ($PSBoundParameters.ContainsKey('EnvironmentVariables')) {
            $envVars = $EnvironmentVariables
        } elseif ($profile.EnvironmentVariables -is [hashtable]) {
            $envVars = $profile.EnvironmentVariables
        } elseif ($profile.EnvironmentVariables) {
            foreach ($prop in $profile.EnvironmentVariables.PSObject.Properties) {
                $envVars[$prop.Name] = $prop.Value
            }
        }

        $config = [ordered]@{
            name                 = $profile.Name
            pythonPath           = if ($PSBoundParameters.ContainsKey('PythonPath')) { $PythonPath } else { $profile.PythonPath }
            requirementsFile     = if ($ClearRequirementsFile) { $null } elseif ($PSBoundParameters.ContainsKey('RequirementsFile')) { $RequirementsFile } else { $profile.RequirementsFile }
            venvLocation         = if ($PSBoundParameters.ContainsKey('VenvLocation')) { $VenvLocation } elseif ($profile.VenvLocation -eq (Join-Path $root $profile.Name)) { $null } else { $profile.VenvLocation }
            environmentVariables = $envVars
            postActivateScripts  = if ($PSBoundParameters.ContainsKey('PostActivateScripts')) { $PostActivateScripts } else { $profile.PostActivateScripts }
            setLocation          = if ($ClearSetLocation) { $null } elseif ($PSBoundParameters.ContainsKey('SetLocation')) { $SetLocation } else { $profile.SetLocation }
            skipPythonActivation = if ($PSBoundParameters.ContainsKey('SkipPythonActivation')) { [bool]$SkipPythonActivation } else { $profile.SkipPythonActivation }
            skipPowershellInit   = if ($PSBoundParameters.ContainsKey('SkipPowershellInit')) { [bool]$SkipPowershellInit } else { $profile.SkipPowershellInit }
        }

        if ($PSCmdlet.ShouldProcess($profile.ProfilePath, "Update profile settings for '$Name'")) {
            $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $profile.ProfilePath -Encoding UTF8
            Write-Verbose "Profile updated: $($profile.ProfilePath)"
        }

        if ($PassThru) {
            return (Get-VenvProfile -Name $Name -VenvRoot $root)
        }
    }
}
