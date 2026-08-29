BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvExecutablePath.ps1"
    . "$PSScriptRoot\..\Public\Set-Pwshvenv.ps1"
    . "$PSScriptRoot\..\Public\Export-PwshvenvRequirements.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Export-PwshvenvRequirements' {
    BeforeEach {
        $root = New-TempVenvRoot
        New-ProfileJson -Root $root -Name 'myapp' -PythonPath 'python' | Out-Null

        $venvDir = Join-Path $root 'myapp'
        $scriptsDir = Join-Path $venvDir 'Scripts'
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        $mockPip = Join-Path $scriptsDir 'pip.cmd'
        Set-Content -LiteralPath $mockPip -Value "@echo off`necho requests==2.31.0`necho urllib3==2.0.4"
    }

    Context 'validation and error handling' {
        It 'throws if no venv is specified and none is active' {
            $script:PwshvenvActive = $false
            $script:PwshvenvActiveName = $null
            { Export-PwshvenvRequirements -VenvRoot $root } | Should -Throw "*No virtual environment specified*"
        }

        It 'throws if profile does not exist' {
            { Export-PwshvenvRequirements -Name 'ghost' -VenvRoot $root } | Should -Throw "*Profile not found*"
        }
    }

    Context 'exporting to output file' {
        It 'writes frozen requirements to custom -Path' {
            $targetPath = Join-Path $root 'output_reqs.txt'
            Export-PwshvenvRequirements -Name 'myapp' -Path $targetPath -VenvRoot $root

            Test-Path -LiteralPath $targetPath | Should -BeTrue
            $content = Get-Content -LiteralPath $targetPath
            $content | Should -Contain 'requests==2.31.0'
        }

        It 'updates profile when -SaveToProfile is specified' {
            $targetPath = Join-Path $root 'output_reqs.txt'
            Export-PwshvenvRequirements -Name 'myapp' -Path $targetPath -SaveToProfile -VenvRoot $root

            $profile = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $profile.RequirementsFile | Should -Be $targetPath
        }

        It 'returns output array when -PassThru is specified' {
            $lines = Export-PwshvenvRequirements -Name 'myapp' -PassThru -VenvRoot $root
            $lines | Should -Contain 'requests==2.31.0'
        }
    }

    Context 'exporting from active venv' {
        BeforeEach {
            $script:PwshvenvActive = $true
            $script:PwshvenvActiveName = 'myapp'
        }

        AfterEach {
            $script:PwshvenvActive = $false
            $script:PwshvenvActiveName = $null
        }

        It 'automatically uses active venv when -Name is omitted' {
            $targetPath = Join-Path $root 'active_reqs.txt'
            Export-PwshvenvRequirements -Path $targetPath -VenvRoot $root
            Test-Path -LiteralPath $targetPath | Should -BeTrue
        }
    }
}
