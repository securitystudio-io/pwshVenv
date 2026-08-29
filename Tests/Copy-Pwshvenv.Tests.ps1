BeforeAll {
    function python { }
    function python3.11 { }
    function pip { }

    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Public\New-Pwshvenv.ps1"
    . "$PSScriptRoot\..\Public\Copy-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Copy-Pwshvenv' {
    BeforeEach {
        $root = New-TempVenvRoot
        Mock python { $global:LASTEXITCODE = 0 }
        Mock python3.11 { $global:LASTEXITCODE = 0 }
        Mock pip { $global:LASTEXITCODE = 0 }
    }

    Context 'cloning profile JSON' {
        BeforeEach {
            New-ProfileJson -Root $root -Name 'source-app' -PythonPath 'python' -SetLocation 'C:\Source' -EnvironmentVariables @{ API = '123' } | Out-Null
        }

        It 'creates a new profile JSON with inherited settings' {
            Copy-Pwshvenv -Name 'source-app' -Destination 'dest-app' -VenvRoot $root
            $destProfile = Get-VenvProfile -Name 'dest-app' -VenvRoot $root
            $destProfile.Name | Should -Be 'dest-app'
            $destProfile.PythonPath | Should -Be 'python'
            $destProfile.SetLocation | Should -Be 'C:\Source'
            $destProfile.EnvironmentVariables.API | Should -Be '123'
        }

        It 'applies field overrides on destination profile' {
            Copy-Pwshvenv -Name 'source-app' -Destination 'dest-app' -PythonPath 'python3.11' -SetLocation 'C:\Dest' -VenvRoot $root
            $destProfile = Get-VenvProfile -Name 'dest-app' -VenvRoot $root
            $destProfile.PythonPath | Should -Be 'python3.11'
            $destProfile.SetLocation | Should -Be 'C:\Dest'
        }

        It 'throws if destination profile already exists and -Force is not passed' {
            New-ProfileJson -Root $root -Name 'dest-app' | Out-Null
            { Copy-Pwshvenv -Name 'source-app' -Destination 'dest-app' -VenvRoot $root } | Should -Throw "*already exists*"
        }

        It 'overwrites destination profile when -Force is passed' {
            New-ProfileJson -Root $root -Name 'dest-app' -PythonPath 'old' | Out-Null
            Copy-Pwshvenv -Name 'source-app' -Destination 'dest-app' -Force -VenvRoot $root
            $destProfile = Get-VenvProfile -Name 'dest-app' -VenvRoot $root
            $destProfile.PythonPath | Should -Be 'python'
        }

        It 'returns destination profile with -PassThru' {
            $dest = Copy-Pwshvenv -Name 'source-app' -Destination 'dest-app' -PassThru -VenvRoot $root
            $dest.Name | Should -Be 'dest-app'
        }
    }

    Context 'with -CreateVenv' {
        It 'invokes New-Pwshvenv to instantiate the new virtual environment' {
            New-ProfileJson -Root $root -Name 'source-app' -PythonPath 'python' | Out-Null
            $dest = Copy-Pwshvenv -Name 'source-app' -Destination 'dest-app' -CreateVenv -PassThru -VenvRoot $root -WhatIf:$false
            $dest.Name | Should -Be 'dest-app'
            Join-Path $root 'dest-app.json' | Should -Exist
        }
    }

    Context 'error handling' {
        It 'throws when source profile does not exist' {
            { Copy-Pwshvenv -Name 'ghost' -Destination 'dest-app' -VenvRoot $root } | Should -Throw "*Profile not found*"
        }
    }
}
