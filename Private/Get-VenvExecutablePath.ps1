function Get-VenvExecutablePath {
    <#
    .SYNOPSIS
        Resolves the cross-platform path to an executable or script inside a virtual environment.
    .DESCRIPTION
        Inspects the virtual environment directory structure across Windows ('Scripts') and
        Unix/macOS ('bin') to locate requested binaries or activation scripts (e.g. Activate.ps1,
        pip, python).
    .PARAMETER VenvLocation
        The root directory of the virtual environment.
    .PARAMETER ExecutableName
        The name of the executable or script (e.g. 'Activate.ps1', 'pip', 'python').
    .OUTPUTS
        Absolute path to the executable or script.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $VenvLocation,

        [Parameter(Mandatory)]
        [string] $ExecutableName
    )

    $isWin = $IsWindows -or ($env:OS -and $env:OS -match 'Windows')
    $candidateDirs = if ($isWin) { @('Scripts', 'bin') } else { @('bin', 'Scripts') }

    foreach ($sub in $candidateDirs) {
        $dir = Join-Path $VenvLocation $sub
        $candidates = @($ExecutableName)

        if ($isWin -and $ExecutableName -notmatch '\.(exe|ps1|cmd|bat)$') {
            $candidates += "$ExecutableName.exe", "$ExecutableName.cmd", "$ExecutableName.bat"
        }
        if ($ExecutableName -match '(?i)^activate$' -or $ExecutableName -match '(?i)^activate\.ps1$') {
            $candidates += 'Activate.ps1', 'activate.ps1'
        }

        foreach ($cand in $candidates) {
            $fullPath = Join-Path $dir $cand
            if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
                return $fullPath
            }
        }
    }

    # Default fallback path
    $primarySub = if ($isWin) { 'Scripts' } else { 'bin' }
    $defaultExt = if ($isWin -and $ExecutableName -notmatch '\.(exe|ps1)$') {
        if ($ExecutableName -match '(?i)activate') { '.ps1' } else { '.exe' }
    } else {
        ''
    }
    return Join-Path (Join-Path $VenvLocation $primarySub) "$ExecutableName$defaultExt"
}
