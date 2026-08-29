BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvExecutablePath.ps1"
    . "$PSScriptRoot\..\Public\Update-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Update-Pwshvenv' {
    BeforeEach {
        $root = New-TempVenvRoot
    }

    Context 'error handling' {
        It 'throws when the profile does not exist' {
            { Update-Pwshvenv -Name 'ghost' -VenvRoot $root } | Should -Throw '*Profile not found*'
        }
    }

    Context 'venv rebuild' {
        It 'removes the existing venv directory before recreating it' {
            New-ProfileJson -Root $root -Name 'myapp' | Out-Null
            $venvDir = Join-Path $root 'myapp'
            New-Item -ItemType Directory -Path $venvDir -Force | Out-Null
            $sentinel = Join-Path $venvDir 'old-file.txt'
            'old' | Set-Content -LiteralPath $sentinel -Encoding UTF8

            # Stub python so the re-create step doesn't fail.
            Mock -CommandName python -MockWith { $global:LASTEXITCODE = 0 }

            Update-Pwshvenv -Name 'myapp' -VenvRoot $root -Confirm:$false
            Test-Path -LiteralPath $sentinel | Should -BeFalse
        }

        It 'throws when the python interpreter exits non-zero' {
            New-ProfileJson -Root $root -Name 'myapp' | Out-Null
            Mock -CommandName python -MockWith { $global:LASTEXITCODE = 1 }

            { Update-Pwshvenv -Name 'myapp' -VenvRoot $root -Confirm:$false } |
                Should -Throw '*venv creation failed*'
        }
    }

    Context 'requirements install' {
        It 'emits a warning when requirements file is listed in profile but does not exist on disk' {
            New-ProfileJson -Root $root -Name 'myapp' -RequirementsFile 'C:\ghost-req.txt' | Out-Null
            Mock -CommandName python -MockWith { $global:LASTEXITCODE = 0 }

            Update-Pwshvenv -Name 'myapp' -VenvRoot $root -Confirm:$false 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] } |
                Select-Object -ExpandProperty Message |
                Should -Match 'Requirements file not found'
        }
    }
}
