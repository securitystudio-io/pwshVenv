function Set-PwshvenvEnvironmentVariable {
    <#
    .SYNOPSIS
        Adds or updates an environment variable in an existing pwshvenv profile.
    .DESCRIPTION
        Updates the 'environmentVariables' hashtable in the JSON configuration file for a specified pwshvenv.
        This does not affect currently active sessions but will apply to any new sessions that use this venv.
    .PARAMETER Name
        The name of the virtual environment to update.
    .PARAMETER Key
        The name of the environment variable to add or update.
    .PARAMETER Value
        The value to assign to the environment variable.
    .PARAMETER VenvRoot
        Directory where profile JSON files are stored. Uses Resolve-VenvRoot when omitted.
    .EXAMPLE
        Set-PwshvenvEnvironmentVariable -Name 'myapp' -Key 'MY_API_KEY' -Value 'secret123'
        Adds MY_API_KEY=secret123 to the 'myapp' venv profile.
    .NOTES
        Requires the pwshVenv module to be loaded.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter(Mandatory)]
        [string] $Value,

        [string] $VenvRoot
    )

    $root = Resolve-VenvRoot -VenvRoot $VenvRoot
    
    # Load existing profile
    $profile = Get-VenvProfile -Name $Name -VenvRoot $root

    if ($PSCmdlet.ShouldProcess($profile.ProfilePath, "Update environment variable '$Key' to '$Value'")) {
        # Convert EnvironmentVariables to hashtable if it is a PSCustomObject
        $envVars = @{}
        if ($profile.EnvironmentVariables -is [hashtable]) {
            $envVars = $profile.EnvironmentVariables
        } else {
            foreach ($prop in $profile.EnvironmentVariables.PSObject.Properties) {
                $envVars[$prop.Name] = $prop.Value
            }
        }

        # Update the hashtable
        $envVars[$Key] = $Value

        # Prepare the updated configuration object for writing
        # We need to reconstruct the structure that New-Pwshvenv uses
        $config = [ordered]@{
            name                 = $profile.Name
            pythonPath           = $profile.PythonPath
            requirementsFile     = $profile.RequirementsFile
            venvLocation         = if ($profile.VenvLocation -eq (Join-Path $root $profile.Name)) { $null } else { $profile.VenvLocation }
            environmentVariables = $envVars
            postActivateScripts  = $profile.PostActivateScripts
            skipPythonActivation = $profile.SkipPythonActivation
            skipPowershellInit   = $profile.SkipPowershellInit
        }

        # Write back to JSON
        $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $profile.ProfilePath -Encoding UTF8
        Write-Verbose "Environment variable '$Key' updated in profile: $($profile.ProfilePath)"
    }
}