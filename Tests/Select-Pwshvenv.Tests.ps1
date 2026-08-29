BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Private\Invoke-VenvTerminalSelector.ps1"
    . "$PSScriptRoot\..\Public\Enter-Pwshvenv.ps1"
    . "$PSScriptRoot\..\Public\Get-Pwshvenv.ps1"
    . "$PSScriptRoot\..\Public\Select-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Select-Pwshvenv' {
    BeforeEach {
        $root = New-TempVenvRoot
    }

    Context 'when no profiles exist' {
        It 'emits a warning and returns null' {
            $warnings = Select-Pwshvenv -VenvRoot $root 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] } |
                Select-Object -ExpandProperty Message

            $warnings | Should -Match 'No pwshVenv profiles found'
        }
    }

    Context 'when profiles exist and selection is made' {
        BeforeEach {
            New-ProfileJson -Root $root -Name 'app1' -PythonPath 'python3.11' | Out-Null
            New-ProfileJson -Root $root -Name 'app2' -PythonPath 'python3.12' -SetLocation 'C:\Projects\app2' | Out-Null
        }

        It 'invokes Enter-Pwshvenv with selected profile' {
            $selectedObj = [PSCustomObject]@{ Name = 'app2' }
            Mock Invoke-VenvTerminalSelector { $selectedObj }
            Mock Enter-Pwshvenv { }

            Select-Pwshvenv -VenvRoot $root

            Should -Invoke Enter-Pwshvenv -Times 1 -ParameterFilter {
                $Name -eq 'app2' -and $VenvRoot -eq $root
            }
        }

        It 'passes skip flags to Enter-Pwshvenv' {
            $selectedObj = [PSCustomObject]@{ Name = 'app1' }
            Mock Invoke-VenvTerminalSelector { $selectedObj }
            Mock Enter-Pwshvenv { }

            Select-Pwshvenv -VenvRoot $root -SkipPythonActivation -SkipPowershellInit

            Should -Invoke Enter-Pwshvenv -Times 1 -ParameterFilter {
                $Name -eq 'app1' -and $SkipPythonActivation -eq $true -and $SkipPowershellInit -eq $true
            }
        }

        It 'returns selected profile when -PassThru is specified' {
            $selectedObj = [PSCustomObject]@{ Name = 'app2' }
            Mock Invoke-VenvTerminalSelector { $selectedObj }
            Mock Enter-Pwshvenv { }

            $result = Select-Pwshvenv -VenvRoot $root -PassThru
            $result.Name | Should -Be 'app2'
        }

        It 'does not invoke Enter-Pwshvenv when selection is cancelled' {
            Mock Invoke-VenvTerminalSelector { $null }
            Mock Enter-Pwshvenv { }

            Select-Pwshvenv -VenvRoot $root

            Should -Invoke Enter-Pwshvenv -Times 0
        }
    }
}
