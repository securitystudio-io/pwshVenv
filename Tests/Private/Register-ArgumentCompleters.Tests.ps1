BeforeAll {
    . "$PSScriptRoot\..\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\..\Private\Register-ArgumentCompleters.ps1"
    . "$PSScriptRoot\..\TestHelpers.ps1"
}

Describe 'Register-PwshvenvArgumentCompleters' {
    It 'executes without error' {
        { Register-PwshvenvArgumentCompleters } | Should -Not -Throw
    }
}
