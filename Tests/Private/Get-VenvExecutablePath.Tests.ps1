BeforeAll {
    . "$PSScriptRoot\..\..\Private\Get-VenvExecutablePath.ps1"
    . "$PSScriptRoot\..\TestHelpers.ps1"
}

Describe 'Get-VenvExecutablePath' {
    BeforeEach {
        $root = New-TempVenvRoot
        $venvDir = Join-Path $root 'test-venv'
        New-Item -ItemType Directory -Path $venvDir -Force | Out-Null
    }

    Context 'when executable exists on disk' {
        It 'resolves Activate.ps1 in Scripts directory' {
            $scriptsDir = Join-Path $venvDir 'Scripts'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            $actFile = Join-Path $scriptsDir 'Activate.ps1'
            Set-Content -LiteralPath $actFile -Value '# test'

            $resolved = Get-VenvExecutablePath -VenvLocation $venvDir -ExecutableName 'Activate.ps1'
            $resolved | Should -Be $actFile
        }

        It 'resolves activate.ps1 in bin directory (Unix style)' {
            $binDir = Join-Path $venvDir 'bin'
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null
            $actFile = Join-Path $binDir 'activate.ps1'
            Set-Content -LiteralPath $actFile -Value '# test'

            $resolved = Get-VenvExecutablePath -VenvLocation $venvDir -ExecutableName 'activate.ps1'
            $resolved | Should -Be $actFile
        }

        It 'resolves pip in bin directory when bin exists' {
            $binDir = Join-Path $venvDir 'bin'
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null
            $pipFile = Join-Path $binDir 'pip'
            Set-Content -LiteralPath $pipFile -Value '# test'

            $resolved = Get-VenvExecutablePath -VenvLocation $venvDir -ExecutableName 'pip'
            $resolved | Should -Be $pipFile
        }
    }

    Context 'when executable does not yet exist on disk' {
        It 'returns default path based on current OS' {
            $resolved = Get-VenvExecutablePath -VenvLocation $venvDir -ExecutableName 'pip'
            $resolved | Should -Match 'pip(\.exe)?$'
        }
    }
}
