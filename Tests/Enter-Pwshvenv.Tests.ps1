BeforeAll {
    . "$PSScriptRoot\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\Private\Invoke-PostActivateScripts.ps1"
    . "$PSScriptRoot\..\Public\Enter-Pwshvenv.ps1"
    . "$PSScriptRoot\..\Public\Exit-Pwshvenv.ps1"
    . "$PSScriptRoot\TestHelpers.ps1"
}

AfterEach {
    Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue
    Remove-Item Env:\PWSHVENV_TEST_VAR -ErrorAction SilentlyContinue
    $script:PwshvenvSnapshot        = $null
    $script:PwshvenvActive          = $false
    $script:PwshvenvPythonActivated = $false
}

# Builds a fake venv structure so Activate.ps1 is present.
function New-FakeVenv {
    param([string]$Root, [string]$Name, [hashtable]$EnvVars)

    New-ProfileJson -Root $Root -Name $Name -EnvironmentVariables $EnvVars | Out-Null
    $scriptsDir = Join-Path $Root $Name 'Scripts'
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    @'
$env:VIRTUAL_ENV = (Split-Path $PSScriptRoot)
function deactivate { Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue }
'@ | Set-Content -LiteralPath (Join-Path $scriptsDir 'Activate.ps1') -Encoding UTF8
}

Describe 'Enter-Pwshvenv' {
    BeforeEach { $root = New-TempVenvRoot }

    Context 'error handling' {
        It 'throws when the profile does not exist' {
            { Enter-Pwshvenv -Name 'ghost' -VenvRoot $root } | Should -Throw '*Profile not found*'
        }

        It 'throws when Activate.ps1 is missing from the venv directory' {
            New-ProfileJson -Root $root -Name 'myapp' | Out-Null
            { Enter-Pwshvenv -Name 'myapp' -VenvRoot $root } | Should -Throw '*Activate.ps1 not found*'
        }

        It 'warns and returns when a pwshVenv environment is already active' {
            $script:PwshvenvActive = $true
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{}
            $warnings = Enter-Pwshvenv -Name 'myapp' -VenvRoot $root 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'full activation (no skip flags)' {
        It 'sets VIRTUAL_ENV after activation' {
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{}
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root
            $env:VIRTUAL_ENV | Should -Not -BeNullOrEmpty
        }

        It 'applies environment variables from the profile' {
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{ PWSHVENV_TEST_VAR = 'hello' }
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root
            $env:PWSHVENV_TEST_VAR | Should -Be 'hello'
        }

        It 'saves a pre-activation snapshot of env vars' {
            $env:PWSHVENV_TEST_VAR = 'original'
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{ PWSHVENV_TEST_VAR = 'new' }
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root
            $script:PwshvenvSnapshot['PWSHVENV_TEST_VAR'] | Should -Be 'original'
        }

        It 'sets PwshvenvActive to true' {
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{}
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root
            $script:PwshvenvActive | Should -BeTrue
        }
    }

    Context '-SkipPythonActivation' {
        It 'does not set VIRTUAL_ENV when skip flag is passed as parameter' {
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{ PWSHVENV_TEST_VAR = 'set' }
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root -SkipPythonActivation
            $env:VIRTUAL_ENV | Should -BeNullOrEmpty
        }

        It 'still applies env vars when only Python activation is skipped' {
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{ PWSHVENV_TEST_VAR = 'set' }
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root -SkipPythonActivation
            $env:PWSHVENV_TEST_VAR | Should -Be 'set'
        }

        It 'honours skipPythonActivation from the profile JSON' {
            New-ProfileJson -Root $root -Name 'myapp' `
                -EnvironmentVariables @{ PWSHVENV_TEST_VAR = 'set' } | Out-Null
            # Patch the JSON to include skipPythonActivation = true
            $jsonPath = Join-Path $root 'myapp.json'
            $raw = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
            $raw | Add-Member -NotePropertyName 'skipPythonActivation' -NotePropertyValue $true -Force
            $raw | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

            # No Activate.ps1 created — would throw if Python activation ran
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root
            $env:VIRTUAL_ENV | Should -BeNullOrEmpty
        }
    }

    Context '-SkipPowershellInit' {
        It 'does not set env vars when skip flag is passed as parameter' {
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{ PWSHVENV_TEST_VAR = 'should-not-be-set' }
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root -SkipPowershellInit
            $env:PWSHVENV_TEST_VAR | Should -BeNullOrEmpty
        }

        It 'still activates Python when only PowerShell init is skipped' {
            New-FakeVenv -Root $root -Name 'myapp' -EnvVars @{}
            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root -SkipPowershellInit
            $env:VIRTUAL_ENV | Should -Not -BeNullOrEmpty
        }

        It 'honours skipPowershellInit from the profile JSON' {
            New-ProfileJson -Root $root -Name 'myapp' `
                -EnvironmentVariables @{ PWSHVENV_TEST_VAR = 'should-not-be-set' } | Out-Null
            $jsonPath = Join-Path $root 'myapp.json'
            $raw = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
            $raw | Add-Member -NotePropertyName 'skipPowershellInit' -NotePropertyValue $true -Force
            $raw | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

            $scriptsDir = Join-Path $root 'myapp' 'Scripts'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            @'
$env:VIRTUAL_ENV = (Split-Path $PSScriptRoot)
function deactivate { Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue }
'@ | Set-Content -LiteralPath (Join-Path $scriptsDir 'Activate.ps1') -Encoding UTF8

            Enter-Pwshvenv -Name 'myapp' -VenvRoot $root
            $env:PWSHVENV_TEST_VAR | Should -BeNullOrEmpty
        }
    }
}

Describe 'Exit-Pwshvenv' {
    BeforeEach { $root = New-TempVenvRoot }

    Context 'when no venv is active' {
        It 'is a no-op and does not throw' {
            $script:PwshvenvActive = $false
            { Exit-Pwshvenv } | Should -Not -Throw
        }
    }

    Context 'when a venv is active' {
        BeforeEach {
            $script:PwshvenvActive          = $true
            $script:PwshvenvPythonActivated = $true
            $env:VIRTUAL_ENV                = 'fake-venv'
            function global:deactivate { Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue }
        }

        AfterEach {
            Remove-Item Function:\deactivate -ErrorAction SilentlyContinue
        }

        It 'calls deactivate and clears VIRTUAL_ENV' {
            Exit-Pwshvenv
            $env:VIRTUAL_ENV | Should -BeNullOrEmpty
        }

        It 'restores env vars from the snapshot' {
            $env:PWSHVENV_TEST_VAR           = 'new-value'
            $script:PwshvenvSnapshot         = @{ PWSHVENV_TEST_VAR = 'original' }
            Exit-Pwshvenv
            $env:PWSHVENV_TEST_VAR | Should -Be 'original'
        }

        It 'sets PwshvenvActive to false' {
            Exit-Pwshvenv
            $script:PwshvenvActive | Should -BeFalse
        }

        It 'clears the snapshot after restoring' {
            $script:PwshvenvSnapshot = @{ SOME_VAR = $null }
            Exit-Pwshvenv
            $script:PwshvenvSnapshot | Should -BeNullOrEmpty
        }
    }

    Context 'when Python activation was skipped' {
        It 'does not attempt to call deactivate' {
            $script:PwshvenvActive          = $true
            $script:PwshvenvPythonActivated = $false
            $script:PwshvenvSnapshot        = @{ PWSHVENV_TEST_VAR = 'original' }
            $env:PWSHVENV_TEST_VAR          = 'new-value'

            # deactivate is NOT defined — would throw if called
            { Exit-Pwshvenv } | Should -Not -Throw
            $env:PWSHVENV_TEST_VAR | Should -Be 'original'
        }
    }
}
