BeforeAll {
    . "$PSScriptRoot\..\..\Private\Invoke-VenvTerminalSelector.ps1"
}

Describe 'Invoke-VenvTerminalSelector' {
    Context 'when profiles array is empty' {
        It 'returns null without throwing' {
            $result = Invoke-VenvTerminalSelector -Profiles @()
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when environment is non-interactive' {
        It 'returns first profile in non-interactive mode' {
            $profiles = @(
                [PSCustomObject]@{ Name = 'p1' },
                [PSCustomObject]@{ Name = 'p2' }
            )
            $result = Invoke-VenvTerminalSelector -Profiles $profiles
            $result.Name | Should -Be 'p1'
        }
    }
}
