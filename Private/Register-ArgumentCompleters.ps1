function Register-PwshvenvArgumentCompleters {
    <#
    .SYNOPSIS
        Registers dynamic tab completion for the -Name parameter across pwshVenv cmdlets.
    #>
    [CmdletBinding()]
    param()

    $scriptBlock = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $venvRoot = if ($fakeBoundParameters -and $fakeBoundParameters.ContainsKey('VenvRoot')) {
            $fakeBoundParameters['VenvRoot']
        } else {
            $null
        }

        try {
            $root = Resolve-VenvRoot -VenvRoot $venvRoot
            $files = Get-ChildItem -LiteralPath $root -Filter '*.json' -File -ErrorAction SilentlyContinue
            if ($files) {
                foreach ($file in $files) {
                    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    if ($null -eq $wordToComplete -or $wordToComplete -eq '' -or $name -like "$wordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new($name, $name, [System.Management.Automation.CompletionResultType]::ParameterValue, "pwshVenv: $name")
                    }
                }
            }
        } catch { }
    }

    $commands = @(
        'Get-Pwshvenv',
        'Enter-Pwshvenv',
        'Update-Pwshvenv',
        'Remove-Pwshvenv',
        'Set-Pwshvenv',
        'Copy-Pwshvenv',
        'Set-PwshvenvEnvironmentVariable',
        'Export-PwshvenvRequirements',
        'Install-PwshvenvPackage',
        'workon'
    )

    foreach ($cmd in $commands) {
        Register-ArgumentCompleter -CommandName $cmd -ParameterName 'Name' -ScriptBlock $scriptBlock -ErrorAction SilentlyContinue
    }
}
