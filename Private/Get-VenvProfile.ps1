function Get-VenvProfile {
    <#
    .SYNOPSIS
        Loads and validates a venv profile from a JSON file.
    .DESCRIPTION
        Reads a JSON profile stored at <VenvRoot>\<Name>.json and returns a PSCustomObject
        with all profile fields. Throws if the file does not exist or if the required 'name'
        field is missing. Optional fields (pythonPath, requirementsFile, venvLocation,
        environmentVariables, postActivateScripts, setLocation, skipPythonActivation,
        skipPowershellInit) are returned as $null/$false when absent.
    .PARAMETER Name
        The profile name. The file <VenvRoot>\<Name>.json must exist.
    .PARAMETER VenvRoot
        The directory that contains profile JSON files. Uses Resolve-VenvRoot when omitted.
    .OUTPUTS
        PSCustomObject with properties: Name, PythonPath, RequirementsFile, VenvLocation,
        EnvironmentVariables, PostActivateScripts, SetLocation, SkipPythonActivation,
        SkipPowershellInit, ProfilePath.
    .EXAMPLE
        $profile = Get-VenvProfile -Name 'myapp'
    .NOTES
        Used internally by New-Pwshvenv, Enter-Pwshvenv, Update-Pwshvenv, and Get-Pwshvenv.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [string] $VenvRoot
    )

    $root        = Resolve-VenvRoot -VenvRoot $VenvRoot
    $profilePath = Join-Path $root "$Name.json"

    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        throw "Profile not found: $profilePath"
    }

    $raw = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

    if (-not $raw.name) {
        throw "Profile '$profilePath' is missing the required 'name' field."
    }

    $resolvedVenvLocation = if ($raw.venvLocation) {
        $raw.venvLocation
    } else {
        Join-Path $root $raw.name
    }

    return [PSCustomObject]@{
        Name                  = $raw.name
        PythonPath            = $raw.pythonPath
        RequirementsFile      = $raw.requirementsFile
        VenvLocation          = $resolvedVenvLocation
        EnvironmentVariables  = $raw.environmentVariables
        PostActivateScripts   = $raw.postActivateScripts
        SetLocation           = $raw.setLocation
        SkipPythonActivation  = [bool]$raw.skipPythonActivation
        SkipPowershellInit    = [bool]$raw.skipPowershellInit
        ProfilePath           = $profilePath
    }
}
