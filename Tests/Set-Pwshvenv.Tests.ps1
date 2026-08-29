BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Public\Set-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'Set-Pwshvenv' {
    BeforeEach {
        $root = New-TempVenvRoot
    }

    Context 'property updates' {
        BeforeEach {
            New-ProfileJson -Root $root -Name 'myapp' -PythonPath 'python' -SetLocation 'C:\Old' -RequirementsFile 'C:\req.txt' | Out-Null
        }

        It 'updates SetLocation' {
            Set-Pwshvenv -Name 'myapp' -SetLocation 'C:\New' -VenvRoot $root
            $profile = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $profile.SetLocation | Should -Be 'C:\New'
        }

        It 'updates PythonPath' {
            Set-Pwshvenv -Name 'myapp' -PythonPath 'python3.12' -VenvRoot $root
            $profile = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $profile.PythonPath | Should -Be 'python3.12'
        }

        It 'clears SetLocation with -ClearSetLocation' {
            Set-Pwshvenv -Name 'myapp' -ClearSetLocation -VenvRoot $root
            $profile = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $profile.SetLocation | Should -BeNullOrEmpty
        }

        It 'clears RequirementsFile with -ClearRequirementsFile' {
            Set-Pwshvenv -Name 'myapp' -ClearRequirementsFile -VenvRoot $root
            $profile = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $profile.RequirementsFile | Should -BeNullOrEmpty
        }

        It 'updates EnvironmentVariables' {
            Set-Pwshvenv -Name 'myapp' -EnvironmentVariables @{ FOO = 'bar' } -VenvRoot $root
            $profile = Get-VenvProfile -Name 'myapp' -VenvRoot $root
            $profile.EnvironmentVariables.FOO | Should -Be 'bar'
        }

        It 'returns updated profile when -PassThru is specified' {
            $updated = Set-Pwshvenv -Name 'myapp' -SetLocation 'C:\Projects' -PassThru -VenvRoot $root
            $updated.SetLocation | Should -Be 'C:\Projects'
            $updated.Name | Should -Be 'myapp'
        }
    }

    Context 'error handling' {
        It 'throws when profile does not exist' {
            { Set-Pwshvenv -Name 'ghost' -SetLocation 'C:\Temp' -VenvRoot $root } | Should -Throw "*Profile not found*"
        }
    }
}
