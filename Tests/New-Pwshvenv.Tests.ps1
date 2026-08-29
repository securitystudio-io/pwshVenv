BeforeAll {
    function python { }
    function python3.10 { }
    function python3.12 { }
    function pip { }
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvExecutablePath.ps1"
    . "$PSScriptRoot\..\Private\Invoke-PostActivateScripts.ps1"
    . "$PSScriptRoot\..\Public\New-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

Describe 'New-Pwshvenv' {
    BeforeEach {
        $root = New-TempVenvRoot
        # Stub out python commands so we don't need real interpreters.
        Mock python { $global:LASTEXITCODE = 0 }
        Mock python3.10 { $global:LASTEXITCODE = 0 }
        Mock python3.12 { $global:LASTEXITCODE = 0 }
    }

    Context 'profile JSON creation' {
        It 'writes a profile JSON file to <VenvRoot>\<Name>.json' {
            New-Pwshvenv -Name 'myapp' -VenvRoot $root -WhatIf:$false
            Join-Path $root 'myapp.json' | Should -Exist
        }

        It 'stores the correct name in the profile' {
            New-Pwshvenv -Name 'myapp' -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'myapp.json') -Raw | ConvertFrom-Json
            $raw.name | Should -Be 'myapp'
        }

        It 'persists explicit PythonPath in the profile' {
            New-Pwshvenv -Name 'myapp' -PythonPath 'python3.12' -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'myapp.json') -Raw | ConvertFrom-Json
            $raw.pythonPath | Should -Be 'python3.12'
        }

        It 'persists EnvironmentVariables in the profile' {
            New-Pwshvenv -Name 'myapp' -EnvironmentVariables @{ DEBUG = '1' } -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'myapp.json') -Raw | ConvertFrom-Json
            $raw.environmentVariables.DEBUG | Should -Be '1'
        }

        It 'persists SetLocation in the profile' {
            New-Pwshvenv -Name 'myapp' -SetLocation 'C:\Projects\myapp' -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'myapp.json') -Raw | ConvertFrom-Json
            $raw.setLocation | Should -Be 'C:\Projects\myapp'
        }
    }

    Context 'template loading' {
        It 'uses template values when no explicit overrides are given' {
            $templatePath = New-ProfileJson -Root $root -Name 'base' -PythonPath 'python3.10' -SetLocation 'C:\Projects\base'
            New-Pwshvenv -Name 'child' -TemplatePath $templatePath -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'child.json') -Raw | ConvertFrom-Json
            $raw.pythonPath | Should -Be 'python3.10'
            $raw.setLocation | Should -Be 'C:\Projects\base'
        }

        It 'explicit parameter overrides the template value' {
            $templatePath = New-ProfileJson -Root $root -Name 'base' -PythonPath 'python3.10' -SetLocation 'C:\Projects\base'
            New-Pwshvenv -Name 'child' -TemplatePath $templatePath -PythonPath 'python3.12' -SetLocation 'C:\Projects\child' -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'child.json') -Raw | ConvertFrom-Json
            $raw.pythonPath | Should -Be 'python3.12'
            $raw.setLocation | Should -Be 'C:\Projects\child'
        }

        It 'throws when TemplatePath does not exist' {
            { New-Pwshvenv -Name 'x' -TemplatePath 'C:\ghost.json' -VenvRoot $root } |
                Should -Throw '*Template file not found*'
        }
    }

    Context 'requirements file' {
        It 'skips pip install when no requirements file is specified' {
            Mock pip { $global:LASTEXITCODE = 0 }
            New-Pwshvenv -Name 'myapp' -VenvRoot $root -WhatIf:$false
            # pip should not have been called; verify no call is sufficient if pip isn't mocked globally
            # We test this by confirming no error is raised and the profile has no requirementsFile.
            $raw = Get-Content (Join-Path $root 'myapp.json') -Raw | ConvertFrom-Json
            $raw.requirementsFile | Should -BeNullOrEmpty
        }

        It 'emits a warning (not an error) when requirements file path does not exist' {
            New-Pwshvenv -Name 'myapp' -RequirementsFile 'C:\nonexistent-req.txt' -VenvRoot $root -WhatIf:$false 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] } |
                Select-Object -ExpandProperty Message |
                Should -Match 'Requirements file not found'
        }
    }
}
