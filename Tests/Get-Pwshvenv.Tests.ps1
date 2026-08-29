BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Public\Get-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Get-Pwshvenv' {
    BeforeEach {
        $root = New-TempVenvRoot
    }

    Context 'when VenvRoot is empty' {
        It 'returns no results without throwing' {
            $result = Get-Pwshvenv -VenvRoot $root
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when profiles exist' {
        It 'returns all profiles when -Name is not specified' {
            New-ProfileJson -Root $root -Name 'app1' | Out-Null
            New-ProfileJson -Root $root -Name 'app2' | Out-Null
            $results = Get-Pwshvenv -VenvRoot $root
            $results.Count | Should -Be 2
        }

        It 'filters by -Name and returns only the matching profile' {
            New-ProfileJson -Root $root -Name 'app1' | Out-Null
            New-ProfileJson -Root $root -Name 'app2' | Out-Null
            $result = Get-Pwshvenv -Name 'app1' -VenvRoot $root
            $result | Should -HaveCount 1
            $result.Name | Should -Be 'app1'
        }

        It 'returns empty when -Name does not match any profile' {
            New-ProfileJson -Root $root -Name 'app1' | Out-Null
            $result = Get-Pwshvenv -Name 'ghost' -VenvRoot $root
            $result | Should -BeNullOrEmpty
        }

        It 'deserializes all optional fields' {
            New-ProfileJson -Root $root -Name 'full' `
                -PythonPath 'python3.12' `
                -RequirementsFile 'C:\req.txt' `
                -EnvironmentVariables @{ DEBUG = 'true' } `
                -PostActivateScripts @('C:\setup.ps1') | Out-Null

            $result = Get-Pwshvenv -Name 'full' -VenvRoot $root
            $result.PythonPath           | Should -Be 'python3.12'
            $result.RequirementsFile     | Should -Be 'C:\req.txt'
            $result.PostActivateScripts  | Should -Contain 'C:\setup.ps1'
        }

        It 'emits a warning and skips malformed JSON files without throwing' {
            'not valid json {{' | Set-Content -LiteralPath (Join-Path $root 'bad.json') -Encoding UTF8
            New-ProfileJson -Root $root -Name 'good' | Out-Null
            { $results = Get-Pwshvenv -VenvRoot $root } | Should -Not -Throw
        }
    }

    Context 'when -Active is specified' {
        It 'returns null when no venv is active' {
            $script:PwshvenvActive = $false
            $script:PwshvenvActiveName = $null
            $result = Get-Pwshvenv -Active -VenvRoot $root
            $result | Should -BeNullOrEmpty
        }

        It 'returns active profile when a venv is active' {
            New-ProfileJson -Root $root -Name 'active-app' | Out-Null
            $script:PwshvenvActive = $true
            $script:PwshvenvActiveName = 'active-app'

            $result = Get-Pwshvenv -Active -VenvRoot $root
            $result.Name | Should -Be 'active-app'

            $script:PwshvenvActive = $false
            $script:PwshvenvActiveName = $null
        }
    }
}
