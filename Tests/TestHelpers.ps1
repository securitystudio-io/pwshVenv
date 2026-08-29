<#
.SYNOPSIS
    Shared helpers for the pwshVenv Pester test suite.
.DESCRIPTION
    Provides factory functions for creating temporary directories and profile JSON files
    used across tests. All helpers write to a temp path under $TestDrive so Pester cleans
    up automatically.
#>

function New-TempVenvRoot {
    <#
    .SYNOPSIS
        Creates and returns a temporary directory to act as the VenvRoot.
    #>
    $path = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function New-ProfileJson {
    <#
    .SYNOPSIS
        Writes a profile JSON file to a directory and returns its path.
    .PARAMETER Root
        The directory to write the JSON file into.
    .PARAMETER Name
        Profile name; file is written as <Root>\<Name>.json.
    .PARAMETER PythonPath
    .PARAMETER RequirementsFile
    .PARAMETER VenvLocation
    .PARAMETER EnvironmentVariables
        Hashtable.
    .PARAMETER PostActivateScripts
        String array.
    .PARAMETER SetLocation
        String.
    #>
    param(
        [string]   $Root,
        [string]   $Name            = 'testenv',
        [string]   $PythonPath      = 'python',
        [string]   $RequirementsFile,
        [string]   $VenvLocation,
        [hashtable]$EnvironmentVariables,
        [string[]] $PostActivateScripts,
        [string]   $SetLocation
    )

    $obj = [ordered]@{ name = $Name; pythonPath = $PythonPath }
    if ($RequirementsFile)     { $obj.requirementsFile     = $RequirementsFile }
    if ($VenvLocation)         { $obj.venvLocation         = $VenvLocation }
    if ($EnvironmentVariables) { $obj.environmentVariables = $EnvironmentVariables }
    if ($PostActivateScripts)  { $obj.postActivateScripts  = $PostActivateScripts }
    if ($SetLocation)          { $obj.setLocation          = $SetLocation }

    $jsonPath = Join-Path $Root "$Name.json"
    $obj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    return $jsonPath
}
