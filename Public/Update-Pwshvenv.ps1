function Update-Pwshvenv {
    <#
    .SYNOPSIS
        Rebuilds a Python virtual environment from its saved profile.
    .DESCRIPTION
        Update-Pwshvenv is useful when you need to switch Python versions, repair a broken
        environment, or apply a changed requirements file without creating a new profile.

        The command:
          1. Loads the existing profile from <VenvRoot>\<Name>.json.
          2. Removes the current virtual environment directory.
          3. Recreates the virtual environment using the interpreter in the profile.
          4. If the profile specifies a requirements file, installs packages with pip.

        The profile JSON is not modified. To change profile settings, use New-Pwshvenv with
        the same name (this overwrites the profile) or edit the JSON directly.
    .PARAMETER Name
        The name of the profile to rebuild. Required.
    .PARAMETER VenvRoot
        Directory containing the profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .EXAMPLE
        Update-Pwshvenv -Name myapp
        Tears down and rebuilds the 'myapp' venv using its saved profile settings.
    .NOTES
        If the venv is currently active in this session, deactivate it with Exit-Pwshvenv
        before running Update-Pwshvenv to avoid file-lock errors on Windows.
    .LINK
        New-Pwshvenv
        Get-Pwshvenv
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [string] $VenvRoot
    )

    $root    = Resolve-VenvRoot -VenvRoot $VenvRoot
    $venvProfile = Get-VenvProfile -Name $Name -VenvRoot $root

    $python  = if ($venvProfile.PythonPath) { $venvProfile.PythonPath } else { 'python' }

    if (Test-Path -LiteralPath $venvProfile.VenvLocation -PathType Container) {
        if ($PSCmdlet.ShouldProcess($venvProfile.VenvLocation, 'Remove existing virtual environment')) {
            Remove-Item -LiteralPath $venvProfile.VenvLocation -Recurse -Force
            Write-Verbose "Removed existing venv: $($venvProfile.VenvLocation)"
        }
    }

    if ($PSCmdlet.ShouldProcess($venvProfile.VenvLocation, 'Create virtual environment')) {
        Write-Verbose "Creating venv: & $python -m venv $($venvProfile.VenvLocation)"
        & $python -m venv $venvProfile.VenvLocation
        if ($LASTEXITCODE -ne 0) {
            throw "Python venv creation failed (exit code $LASTEXITCODE). Check that '$python' is a valid interpreter."
        }
    }

    if ($venvProfile.RequirementsFile) {
        if (-not (Test-Path -LiteralPath $venvProfile.RequirementsFile -PathType Leaf)) {
            Write-Warning "Requirements file not found, skipping pip install: $($venvProfile.RequirementsFile)"
        } else {
            $pip = Get-VenvExecutablePath -VenvLocation $venvProfile.VenvLocation -ExecutableName 'pip'
            if ($PSCmdlet.ShouldProcess($venvProfile.RequirementsFile, 'pip install -r')) {
                Write-Verbose "Installing requirements: $pip install -r $($venvProfile.RequirementsFile)"
                & $pip install -r $venvProfile.RequirementsFile
                if ($LASTEXITCODE -ne 0) {
                    throw "pip install failed (exit code $LASTEXITCODE)."
                }
            }
        }
    }

    Write-Output $venvProfile
}
