BeforeAll {
    . "$PSScriptRoot\..\..\Private\Resolve-VenvRoot.ps1"
    . "$PSScriptRoot\..\..\Private\Get-VenvProfile.ps1"
    . "$PSScriptRoot\..\..\Public\New-Pwshvenv.ps1"
    . "$PSScriptRoot\..\..\Public\Set-PwshvenvEnvironmentVariable.ps1"
    . "$PSScriptRoot\..\TestHelpers.ps1"
}

Describe 'Set-PwshvenvEnvironmentVariable' {
    BeforeEach {
        $root = New-TempVenvRoot
        # Create a dummy profile for testing
        $profilePath = Join-Path $root 'testvenv.json'
        $config = [ordered]@{
            name                 = 'testvenv'
            pythonPath           = 'python'
            requirementsFile     = $null
            venvLocation         = $null
            environmentVariables = @{ EXISTING = 'oldvalue' }
            postActivateScripts  = @()
            skipPythonActivation = $false
            skipPowershellInit   = $false
        }
        $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $profilePath -Encoding UTF8
    }

    Context 'Adding and updating variables' {
        It 'adds a new environment variable to the profile' {
            Set-PwshvenvEnvironmentVariable -Name 'testvenv' -Key 'NEW_VAR' -Value 'newvalue' -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'testvenv.json') -Raw | ConvertFrom-Json
            $raw.environmentVariables.NEW_VAR | Should -Be 'newvalue'
        }

        It 'updates an existing environment variable in the profile' {
            Set-PwshvenvEnvironmentVariable -Name 'testvenv' -Key 'EXISTING' -Value 'newvalue' -VenvRoot $root -WhatIf:$false
            $raw = Get-Content (Join-Path $root 'testvenv.json') -Raw | ConvertFrom-Json
            $raw.environmentVariables.EXISTING | Should -Be 'newvalue'
        }
    }

    Context 'Error handling' {
        It 'throws an error if the profile does not exist' {
            { Set-PwshvenvEnvironmentVariable -Name 'nonexistent' -Key 'K' -Value 'V' -VenvRoot $root } | Should -Throw "*Profile not found*"
        }
    }
}