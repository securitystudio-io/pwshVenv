function Install-PwshvenvPackage {
    <#
    .SYNOPSIS
        Installs one or more Python packages into a virtual environment using pip.
    .DESCRIPTION
        Directly executes 'pip install' against a specified virtual environment (or the active
        environment if -Name is omitted), without requiring manual session activation.
    .PARAMETER Package
        One or more package specifications (e.g. 'requests', 'pytest>=7.0', 'fastapi[all]').
    .PARAMETER Name
        The name of the virtual environment to install packages into. Defaults to the active venv.
    .PARAMETER Upgrade
        Passes the -U / --upgrade flag to pip install.
    .PARAMETER AdditionalArguments
        Array of additional raw arguments to pass through to pip.
    .PARAMETER VenvRoot
        Directory containing profile JSON files. Defaults to $env:USERPROFILE\.venv.
    .EXAMPLE
        Install-PwshvenvPackage -Name myapp -Package 'requests', 'pydantic'
        Installs requests and pydantic directly into the 'myapp' virtual environment.
    .EXAMPLE
        Install-PwshvenvPackage -Package 'pytest' -Upgrade
        Upgrades pytest in the currently active virtual environment.
    .LINK
        Export-PwshvenvRequirements
        Get-Pwshvenv
        Update-Pwshvenv
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]] $Package,

        [Parameter(Position = 1)]
        [string] $Name,

        [switch] $Upgrade,

        [string[]] $AdditionalArguments,

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

    $pipArgs = [System.Collections.Generic.List[string]]::new()
    $pipArgs.Add('install')
    if ($Upgrade) {
        $pipArgs.Add('--upgrade')
    }
    foreach ($pkg in $Package) {
        $pipArgs.Add($pkg)
    }
    if ($AdditionalArguments) {
        foreach ($arg in $AdditionalArguments) {
            $pipArgs.Add($arg)
        }
    }

    $targetDesc = "$($Package -join ', ') into venv '$targetName'"
    if ($PSCmdlet.ShouldProcess($profile.VenvLocation, "pip install $targetDesc")) {
        Write-Verbose "Executing: $pip $($pipArgs -join ' ')"
        & $pip @pipArgs
        if ($LASTEXITCODE -ne 0) {
            throw "pip install failed with exit code $LASTEXITCODE."
        }
    }
}
