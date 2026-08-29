function Export-PwshvenvRequirements {
    <#
    .SYNOPSIS
        Exports installed packages from a virtual environment via pip freeze.
    .DESCRIPTION
        Runs 'pip freeze' against a virtual environment. If -Name is omitted, exports from the
        currently active virtual environment.

        The output can be written to the profile's configured requirementsFile, a custom -Path,
        or returned as a string array when -PassThru is used or when no output path is targeted.
    .PARAMETER Name
        The name of the virtual environment to export packages from. Defaults to the active venv.
    .PARAMETER Path
        Custom path where requirements.txt should be written.
    .PARAMETER SaveToProfile
        Saves the target requirements file path to the profile's 'requirementsFile' configuration field.
    .PARAMETER PassThru
        Outputs the captured requirements lines to the pipeline.
    .PARAMETER VenvRoot
        Directory containing profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .EXAMPLE
        Export-PwshvenvRequirements -Name myapp
        Runs pip freeze for 'myapp' and writes to its configured requirementsFile.
    .EXAMPLE
        Export-PwshvenvRequirements -Path .\requirements.txt -SaveToProfile
        Exports from the currently active venv to .\requirements.txt and updates the profile.
    .LINK
        Get-Pwshvenv
        Install-PwshvenvPackage
        Update-Pwshvenv
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string[]])]
    param(
        [Parameter(Position = 0)]
        [string] $Name,

        [string] $Path,

        [switch] $SaveToProfile,

        [switch] $PassThru,

        [string] $VenvRoot
    )

    $root = Resolve-VenvRoot -VenvRoot $VenvRoot

    $targetName = if ($Name) {
        $Name
    } elseif ($script:PwshvenvActive -and $script:PwshvenvActiveName) {
        $script:PwshvenvActiveName
    } else {
        throw "No virtual environment specified and none is currently active. Specify -Name or activate an environment first."
    }

    $profile = Get-VenvProfile -Name $targetName -VenvRoot $root
    $pip = Get-VenvExecutablePath -VenvLocation $profile.VenvLocation -ExecutableName 'pip'

    if (-not (Test-Path -LiteralPath $pip -PathType Leaf)) {
        throw "pip executable not found at '$pip'. Ensure the virtual environment has been created with New-Pwshvenv."
    }

    Write-Verbose "Running: $pip freeze"
    $freezeOutput = & $pip freeze
    if ($LASTEXITCODE -ne 0) {
        throw "pip freeze failed with exit code $LASTEXITCODE."
    }

    $outputPath = if ($Path) {
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    } elseif ($profile.RequirementsFile) {
        $profile.RequirementsFile
    } else {
        $null
    }

    if ($outputPath) {
        if ($PSCmdlet.ShouldProcess($outputPath, 'Write frozen requirements')) {
            $parentDir = Split-Path -Path $outputPath -Parent
            if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            $freezeOutput | Set-Content -LiteralPath $outputPath -Encoding UTF8
            Write-Verbose "Requirements saved to $outputPath"
        }

        if ($SaveToProfile -and $profile.RequirementsFile -ne $outputPath) {
            Set-Pwshvenv -Name $targetName -RequirementsFile $outputPath -VenvRoot $root
        }
    }

    if ($PassThru -or -not $outputPath) {
        return $freezeOutput
    }
}
