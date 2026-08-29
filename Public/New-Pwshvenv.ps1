function New-Pwshvenv {
    <#
    .SYNOPSIS
        Creates a new Python virtual environment and saves its configuration profile.
    .DESCRIPTION
        New-Pwshvenv writes a JSON profile to <VenvRoot>\<Name>.json, then uses the
        specified Python interpreter to create the virtual environment. If a requirements
        file is provided in the profile or as a parameter, the packages are installed
        immediately after creation.

        An existing JSON template can be supplied via -TemplatePath to seed default values.
        Any parameters passed explicitly always take precedence over values from the template.

        The virtual environment itself is stored at <VenvRoot>\<Name>\ unless -VenvLocation
        specifies a custom path.
    .PARAMETER Name
        The name of the virtual environment and its configuration profile. Required.
    .PARAMETER PythonPath
        The Python interpreter to use when creating the venv (e.g. 'python', 'python3.12',
        or a full path). Defaults to 'python' when not specified in the template or as a
        parameter.
    .PARAMETER RequirementsFile
        Absolute path to a requirements.txt file. When provided, packages are installed via
        'pip install -r <file>' immediately after the venv is created.
    .PARAMETER VenvLocation
        Custom path where the virtual environment directory should be created. When omitted,
        defaults to <VenvRoot>\<Name>.
    .PARAMETER EnvironmentVariables
        Hashtable of environment variable key-value pairs to store in the profile. These are
        applied to the session each time Enter-Pwshvenv is called.
    .PARAMETER PostActivateScripts
        Array of paths to PowerShell scripts (.ps1) that are dot-sourced after the venv is
        activated via Enter-Pwshvenv.
    .PARAMETER SetLocation
        Directory path to automatically navigate to via Set-Location when activating the venv
        via Enter-Pwshvenv. Restored to the previous location on Exit-Pwshvenv.
    .PARAMETER SkipPythonActivation
        When set in the profile, Enter-Pwshvenv will not dot-source Activate.ps1. Useful when
        managing env vars and scripts without actually activating a Python interpreter.
    .PARAMETER SkipPowershellInit
        When set in the profile, Enter-Pwshvenv will not apply EnvironmentVariables, SetLocation,
        or run PostActivateScripts. Useful when only the Python venv itself is needed.
    .PARAMETER TemplatePath
        Path to an existing profile JSON file to use as the base configuration. Explicit
        parameters override any values loaded from the template.
    .PARAMETER VenvRoot
        Directory where profile JSON files and virtual environments are stored. Defaults to
        $env:USERPROFILE\.venv.
    .EXAMPLE
        New-Pwshvenv -Name myapp
        Creates a profile and venv at $env:USERPROFILE\.venv\myapp using the default Python.
    .EXAMPLE
        New-Pwshvenv -Name myapp -PythonPath python3.12 -RequirementsFile .\requirements.txt
        Creates a venv with Python 3.12 and installs packages from requirements.txt.
    .EXAMPLE
        New-Pwshvenv -Name myapp -SetLocation C:\Projects\myapp
        Creates a profile and venv that changes the session directory to C:\Projects\myapp on entry.
    .EXAMPLE
        New-Pwshvenv -Name myapp -TemplatePath ~\.venv\baseapp.json
        Creates a new profile using an existing template as the base configuration.
    .NOTES
        Python must be installed and the specified interpreter must be accessible on $env:PATH
        or given as a full path.
    .LINK
        Get-Pwshvenv
        Enter-Pwshvenv
        Update-Pwshvenv
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [string] $PythonPath,

        [string] $RequirementsFile,

        [string] $VenvLocation,

        [hashtable] $EnvironmentVariables,

        [string[]] $PostActivateScripts,

        [string] $SetLocation,

        [switch] $SkipPythonActivation,

        [switch] $SkipPowershellInit,

        [string] $TemplatePath,

        [string] $VenvRoot
    )

    $root = Resolve-VenvRoot -VenvRoot $VenvRoot

    # Seed defaults from a template file if provided
    $config = [ordered]@{
        name                 = $Name
        pythonPath           = 'python'
        requirementsFile     = $null
        venvLocation         = $null
        environmentVariables = @{}
        postActivateScripts  = @()
        setLocation          = $null
        skipPythonActivation = $false
        skipPowershellInit   = $false
    }

    if ($TemplatePath) {
        if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
            throw "Template file not found: $TemplatePath"
        }
        $template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
        if ($template.pythonPath)           { $config.pythonPath           = $template.pythonPath }
        if ($template.requirementsFile)     { $config.requirementsFile     = $template.requirementsFile }
        if ($template.venvLocation)         { $config.venvLocation         = $template.venvLocation }
        if ($template.environmentVariables) { $config.environmentVariables = $template.environmentVariables }
        if ($template.postActivateScripts)  { $config.postActivateScripts  = $template.postActivateScripts }
        if ($template.setLocation)          { $config.setLocation          = $template.setLocation }
        if ($template.PSObject.Properties['skipPythonActivation']) { $config.skipPythonActivation = [bool]$template.skipPythonActivation }
        if ($template.PSObject.Properties['skipPowershellInit'])   { $config.skipPowershellInit   = [bool]$template.skipPowershellInit }
    }

    # Explicit parameters win over template values
    if ($PSBoundParameters.ContainsKey('PythonPath'))           { $config.pythonPath           = $PythonPath }
    if ($PSBoundParameters.ContainsKey('RequirementsFile'))     { $config.requirementsFile     = $RequirementsFile }
    if ($PSBoundParameters.ContainsKey('VenvLocation'))         { $config.venvLocation         = $VenvLocation }
    if ($PSBoundParameters.ContainsKey('EnvironmentVariables')) { $config.environmentVariables = $EnvironmentVariables }
    if ($PSBoundParameters.ContainsKey('PostActivateScripts'))  { $config.postActivateScripts  = $PostActivateScripts }
    if ($PSBoundParameters.ContainsKey('SetLocation'))          { $config.setLocation          = $SetLocation }
    if ($PSBoundParameters.ContainsKey('SkipPythonActivation')) { $config.skipPythonActivation = $SkipPythonActivation.IsPresent }
    if ($PSBoundParameters.ContainsKey('SkipPowershellInit'))   { $config.skipPowershellInit   = $SkipPowershellInit.IsPresent }

    $profilePath     = Join-Path $root "$Name.json"
    $resolvedVenvLoc = if ($config.venvLocation) { $config.venvLocation } else { Join-Path $root $Name }

    if ($PSCmdlet.ShouldProcess($profilePath, 'Write profile JSON')) {
        $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $profilePath -Encoding UTF8
        Write-Verbose "Profile written: $profilePath"
    }

    if ($PSCmdlet.ShouldProcess($resolvedVenvLoc, 'Create virtual environment')) {
        Write-Verbose "Creating venv: & $($config.pythonPath) -m venv $resolvedVenvLoc"
        & $config.pythonPath -m venv $resolvedVenvLoc
        if ($LASTEXITCODE -ne 0) {
            throw "Python venv creation failed (exit code $LASTEXITCODE). Check that '$($config.pythonPath)' is a valid interpreter."
        }
    }

    if ($config.requirementsFile) {
        if (-not (Test-Path -LiteralPath $config.requirementsFile -PathType Leaf)) {
            Write-Warning "Requirements file not found, skipping pip install: $($config.requirementsFile)"
        } else {
            $pip = Get-VenvExecutablePath -VenvLocation $resolvedVenvLoc -ExecutableName 'pip'
            if ($PSCmdlet.ShouldProcess($config.requirementsFile, 'pip install -r')) {
                Write-Verbose "Installing requirements: $pip install -r $($config.requirementsFile)"
                & $pip install -r $config.requirementsFile
                if ($LASTEXITCODE -ne 0) {
                    throw "pip install failed (exit code $LASTEXITCODE)."
                }
            }
        }
    }

    Write-Output (Get-VenvProfile -Name $Name -VenvRoot $root)
}
