BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvExecutablePath.ps1"
    . "$PSScriptRoot\..\Public\Install-PwshvenvPackage.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Install-PwshvenvPackage' {
    BeforeEach {
        $root = New-TempVenvRoot
        New-ProfileJson -Root $root -Name 'myapp' -PythonPath 'python' | Out-Null

        $venvDir = Join-Path $root 'myapp'
        $scriptsDir = Join-Path $venvDir 'Scripts'
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        $mockPip = Join-Path $scriptsDir 'pip.cmd'
        Set-Content -LiteralPath $mockPip -Value "@echo off`necho installed %*"
    }

    Context 'package installation' {
        It 'installs packages into named venv' {
            { Install-PwshvenvPackage -Name 'myapp' -Package 'requests', 'pytest' -VenvRoot $root } | Should -Not -Throw
        }

        It 'supports -Upgrade switch' {
            { Install-PwshvenvPackage -Name 'myapp' -Package 'requests' -Upgrade -VenvRoot $root } | Should -Not -Throw
        }

        It 'supports -AdditionalArguments' {
            { Install-PwshvenvPackage -Name 'myapp' -Package 'requests' -AdditionalArguments @('--no-cache-dir') -VenvRoot $root } | Should -Not -Throw
        }
    }

    Context 'error handling' {
        It 'throws if no venv is specified and none is active' {
            $script:PwshvenvActive = $false
            $script:PwshvenvActiveName = $null
            { Install-PwshvenvPackage -Package 'requests' -VenvRoot $root } | Should -Throw "*No virtual environment specified*"
        }

        It 'throws if profile does not exist' {
            { Install-PwshvenvPackage -Name 'ghost' -Package 'requests' -VenvRoot $root } | Should -Throw "*Profile not found*"
        }
    }
}
