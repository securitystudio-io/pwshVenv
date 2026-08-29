BeforeAll {
    . "$PSScriptRoot\..\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\TestHelpers.ps1"
}

Describe 'Get-VenvProfile' {
    BeforeEach {
        $root = New-TempVenvRoot
    }

    Context 'valid profile' {
        It 'returns a PSCustomObject with all expected properties' {
            New-ProfileJson -Root $root -Name 'myapp' -PythonPath 'python3.11' | Out-Null
            $result = Get-VenvProfile -Name 'myapp' -VenvRoot $root

            $result.Name       | Should -Be 'myapp'
            $result.PythonPath | Should -Be 'python3.11'
            $result.ProfilePath | Should -Be (Join-Path $root 'myapp.json')
        }

        It 'resolves VenvLocation to <VenvRoot>\<Name> when not set in profile' {
            New-ProfileJson -Root $root -Name 'myapp' | Out-Null
            $result = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $result.VenvLocation | Should -Be (Join-Path $root 'myapp')
        }

        It 'uses the custom venvLocation when specified in profile' {
            $customPath = Join-Path $TestDrive 'custom-venv'
            New-ProfileJson -Root $root -Name 'myapp' -VenvLocation $customPath | Out-Null
            $result = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $result.VenvLocation | Should -Be $customPath
        }

        It 'returns null for optional fields when they are absent from the profile' {
            New-ProfileJson -Root $root -Name 'minimal' | Out-Null
            $result = Get-VenvProfile -Name 'minimal' -VenvRoot $root

            $result.RequirementsFile    | Should -BeNullOrEmpty
            $result.EnvironmentVariables | Should -BeNullOrEmpty
            $result.PostActivateScripts  | Should -BeNullOrEmpty
            $result.SetLocation          | Should -BeNullOrEmpty
        }

        It 'deserializes setLocation when present in the profile' {
            New-ProfileJson -Root $root -Name 'locapp' -SetLocation 'C:\Projects\locapp' | Out-Null
            $result = Get-VenvProfile -Name 'locapp' -VenvRoot $root
            $result.SetLocation | Should -Be 'C:\Projects\locapp'
        }
    }

    Context 'error handling' {
        It 'throws when the profile file does not exist' {
            { Get-VenvProfile -Name 'ghost' -VenvRoot $root } | Should -Throw '*Profile not found*'
        }

        It 'throws when the profile JSON is missing the name field' {
            $jsonPath = Join-Path $root 'bad.json'
            '{ "pythonPath": "python" }' | Set-Content -LiteralPath $jsonPath -Encoding UTF8
            { Get-VenvProfile -Name 'bad' -VenvRoot $root } | Should -Throw "*missing the required 'name' field*"
        }
    }
}
