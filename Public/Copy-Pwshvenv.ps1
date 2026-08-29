function Copy-Pwshvenv {
    <#
    .SYNOPSIS
        Copies an existing virtual environment profile to a new profile name.
    .DESCRIPTION
        Clones <VenvRoot>\<Name>.json to <VenvRoot>\<Destination>.json with optional property
        overrides. If -CreateVenv is passed, also creates the new virtual environment directory
        and installs requirements (if specified in the profile).
    .PARAMETER Name
        The name of the source virtual environment profile to clone.
    .PARAMETER Destination
        The name of the new virtual environment profile to create.
    .PARAMETER PythonPath
        Overrides the Python interpreter in the new profile.
    .PARAMETER RequirementsFile
        Overrides the requirements.txt path in the new profile.
    .PARAMETER SetLocation
        Overrides the SetLocation directory in the new profile.
    .PARAMETER CreateVenv
        When specified, immediately creates the new virtual environment on disk using New-Pwshvenv.
    .PARAMETER Force
        Overwrites any existing destination profile JSON.
    .PARAMETER PassThru
        Outputs the newly created profile object.
    .PARAMETER VenvRoot
        Directory containing profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .EXAMPLE
        Copy-Pwshvenv -Name myapp -Destination myapp-dev
        Creates a new myapp-dev.json profile inheriting configuration from myapp.
    .EXAMPLE
        Copy-Pwshvenv -Name myapp -Destination myapp-py311 -PythonPath python3.11 -CreateVenv
        Creates a new profile and creates the virtual environment directory using Python 3.11.
    .LINK
        New-Pwshvenv
        Get-Pwshvenv
        Set-Pwshvenv
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [string] $Destination,

        [string] $PythonPath,

        [string] $RequirementsFile,

        [string] $SetLocation,

        [switch] $CreateVenv,

        [switch] $Force,

        [switch] $PassThru,

        [string] $VenvRoot
    )

    process {
        $root = Resolve-VenvRoot -VenvRoot $VenvRoot
        $sourceProfile = Get-VenvProfile -Name $Name -VenvRoot $root

        $destProfilePath = Join-Path $root "$Destination.json"
        if (Test-Path -LiteralPath $destProfilePath -PathType Leaf) {
            if (-not $Force) {
                throw "Destination profile '$Destination' already exists at '$destProfilePath'. Use -Force to overwrite."
            }
        }

        if ($CreateVenv) {
            $newParams = @{
                Name         = $Destination
                TemplatePath = $sourceProfile.ProfilePath
                VenvRoot     = $root
            }
            if ($PSBoundParameters.ContainsKey('PythonPath'))       { $newParams['PythonPath']       = $PythonPath }
            if ($PSBoundParameters.ContainsKey('RequirementsFile')) { $newParams['RequirementsFile'] = $RequirementsFile }
            if ($PSBoundParameters.ContainsKey('SetLocation'))      { $newParams['SetLocation']      = $SetLocation }

            $result = New-Pwshvenv @newParams
            if ($PassThru) {
                return $result
            }
        } else {
            $envVars = @{}
            if ($sourceProfile.EnvironmentVariables -is [hashtable]) {
                $envVars = $sourceProfile.EnvironmentVariables
            } elseif ($sourceProfile.EnvironmentVariables) {
                foreach ($prop in $sourceProfile.EnvironmentVariables.PSObject.Properties) {
                    $envVars[$prop.Name] = $prop.Value
                }
            }

            $config = [ordered]@{
                name                 = $Destination
                pythonPath           = if ($PSBoundParameters.ContainsKey('PythonPath')) { $PythonPath } else { $sourceProfile.PythonPath }
                requirementsFile     = if ($PSBoundParameters.ContainsKey('RequirementsFile')) { $RequirementsFile } else { $sourceProfile.RequirementsFile }
                venvLocation         = $null
                environmentVariables = $envVars
                postActivateScripts  = $sourceProfile.PostActivateScripts
                setLocation          = if ($PSBoundParameters.ContainsKey('SetLocation')) { $SetLocation } else { $sourceProfile.SetLocation }
                skipPythonActivation = $sourceProfile.SkipPythonActivation
                skipPowershellInit   = $sourceProfile.SkipPowershellInit
            }

            if ($PSCmdlet.ShouldProcess($destProfilePath, "Copy profile '$Name' to '$Destination'")) {
                $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $destProfilePath -Encoding UTF8
                Write-Verbose "Profile copied: $destProfilePath"
            }

            if ($PassThru) {
                return (Get-VenvProfile -Name $Destination -VenvRoot $root)
            }
        }
    }
}
