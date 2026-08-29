BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Public\Exit-Pwshvenv.ps1"
    . "$PSScriptRoot\..\Public\Remove-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Remove-Pwshvenv' {
    BeforeEach {
        $root = New-TempVenvRoot
    }

    Context 'default removal (both profile and venv directory)' {
        It 'deletes profile JSON and venv directory' {
            $profilePath = New-ProfileJson -Root $root -Name 'myapp'
            $venvDir = Join-Path $root 'myapp'
            New-Item -ItemType Directory -Path $venvDir -Force | Out-Null

            Remove-Pwshvenv -Name 'myapp' -VenvRoot $root -Confirm:$false

            Test-Path -LiteralPath $profilePath | Should -BeFalse
            Test-Path -LiteralPath $venvDir | Should -BeFalse
        }
    }

    Context '-KeepVenv' {
        It 'deletes profile JSON but keeps venv directory' {
            $profilePath = New-ProfileJson -Root $root -Name 'myapp'
            $venvDir = Join-Path $root 'myapp'
            New-Item -ItemType Directory -Path $venvDir -Force | Out-Null

            Remove-Pwshvenv -Name 'myapp' -KeepVenv -VenvRoot $root -Confirm:$false

            Test-Path -LiteralPath $profilePath | Should -BeFalse
            Test-Path -LiteralPath $venvDir | Should -BeTrue
        }
    }

    Context '-KeepProfile' {
        It 'deletes venv directory but keeps profile JSON' {
            $profilePath = New-ProfileJson -Root $root -Name 'myapp'
            $venvDir = Join-Path $root 'myapp'
            New-Item -ItemType Directory -Path $venvDir -Force | Out-Null

            Remove-Pwshvenv -Name 'myapp' -KeepProfile -VenvRoot $root -Confirm:$false

            Test-Path -LiteralPath $profilePath | Should -BeTrue
            Test-Path -LiteralPath $venvDir | Should -BeFalse
        }
    }

    Context 'active venv handling' {
        BeforeEach {
            $script:PwshvenvActive = $true
            $env:VIRTUAL_ENV = Join-Path $root 'myapp'
        }

        AfterEach {
            $script:PwshvenvActive = $false
            Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue
        }

        It 'throws error when trying to remove active venv without -Force' {
            New-ProfileJson -Root $root -Name 'myapp' | Out-Null
            { Remove-Pwshvenv -Name 'myapp' -VenvRoot $root -Confirm:$false } | Should -Throw "*currently active*"
        }

        It 'deactivates and removes when -Force is passed' {
            $profilePath = New-ProfileJson -Root $root -Name 'myapp'
            Remove-Pwshvenv -Name 'myapp' -Force -VenvRoot $root -Confirm:$false
            Test-Path -LiteralPath $profilePath | Should -BeFalse
            $script:PwshvenvActive | Should -BeFalse
        }
    }

    Context 'error handling' {
        It 'throws when profile does not exist' {
            { Remove-Pwshvenv -Name 'nonexistent' -VenvRoot $root -Confirm:$false } | Should -Throw "*Profile not found*"
        }
    }
}
