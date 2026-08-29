function Get-Pwshvenv {
    <#
    .SYNOPSIS
        Lists venv profiles stored in the VenvRoot directory.
    .DESCRIPTION
        Reads all JSON files from <VenvRoot> and deserializes each into a profile object.
        When -Name is supplied, only the matching profile is returned. If no profiles exist
        an empty result set is returned rather than an error.

        The VenvLocation property in each returned object is always the resolved absolute path
        (i.e. <VenvRoot>\<Name> when the profile does not specify a custom location).
    .PARAMETER Name
        Optional. When provided, only the profile whose name matches this value is returned.
        Wildcards are not supported.
    .PARAMETER Active
        When specified, returns only the profile currently active in the session, or $null if none is active.
    .PARAMETER VenvRoot
        Directory to search for profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .OUTPUTS
        PSCustomObject with properties: Name, PythonPath, RequirementsFile, VenvLocation,
        EnvironmentVariables, PostActivateScripts, SetLocation, SkipPythonActivation,
        SkipPowershellInit, ProfilePath.
    .EXAMPLE
        Get-Pwshvenv
        Returns all profiles in the default VenvRoot.
    .EXAMPLE
        Get-Pwshvenv -Name myapp
        Returns only the profile named 'myapp'.
    .EXAMPLE
        Get-Pwshvenv -Active
        Returns the profile of the currently active virtual environment.
    .LINK
        New-Pwshvenv
        Enter-Pwshvenv
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string] $Name,

        [switch] $Active,

        [string] $VenvRoot
    )

    $root = Resolve-VenvRoot -VenvRoot $VenvRoot

    if ($Active) {
        if ($script:PwshvenvActive -and $script:PwshvenvActiveName) {
            return (Get-VenvProfile -Name $script:PwshvenvActiveName -VenvRoot $root)
        }
        Write-Verbose 'No virtual environment is currently active in this session.'
        return $null
    }

    $jsonFiles = Get-ChildItem -LiteralPath $root -Filter '*.json' -File -ErrorAction SilentlyContinue

    foreach ($file in $jsonFiles) {
        $profileName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

        if ($Name -and $profileName -ne $Name) {
            continue
        }

        try {
            Get-VenvProfile -Name $profileName -VenvRoot $root
        } catch {
            Write-Warning "Could not parse profile '$($file.FullName)': $_"
        }
    }
}
