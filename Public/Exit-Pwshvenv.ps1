function Exit-Pwshvenv {
    <#
    .SYNOPSIS
        Deactivates the currently active Python virtual environment.
    .DESCRIPTION
        Performs the reverse of Enter-Pwshvenv:

          1. If Python activation was performed during Enter-Pwshvenv, calls the 'deactivate'
             function that was injected into the session by Activate.ps1.
          2. Restores any environment variables that were set by Enter-Pwshvenv to the values
             they held before activation.

        If no pwshVenv environment is currently active the command is a no-op and emits a
        verbose message rather than an error.
    .EXAMPLE
        Exit-Pwshvenv
        Deactivates the active venv and restores the previous environment variable state.
    .NOTES
        This command relies on module-scoped state set by Enter-Pwshvenv. Calling it without
        a preceding Enter-Pwshvenv in the same session is harmless.
    .LINK
        Enter-Pwshvenv
    #>
    [CmdletBinding()]
    param()

    if (-not $script:PwshvenvActive) {
        Write-Verbose 'No pwshVenv environment is currently active.'
        return
    }

    if ($script:PwshvenvPythonActivated) {
        if (Get-Command deactivate -ErrorAction SilentlyContinue) {
            deactivate
        } else {
            Write-Warning "'deactivate' function not found in session. The Python venv may need to be deactivated manually."
        }
    }

    # Restore environment variables that were set during Enter-Pwshvenv.
    if ($script:PwshvenvSnapshot) {
        foreach ($key in $script:PwshvenvSnapshot.Keys) {
            $original = $script:PwshvenvSnapshot[$key]
            Write-Verbose "Restoring env var: $key=$(if ($null -eq $original) { '(removed)' } else { $original })"
            [System.Environment]::SetEnvironmentVariable($key, $original, 'Process')
        }
    }

    $script:PwshvenvSnapshot        = $null
    $script:PwshvenvActive          = $false
    $script:PwshvenvPythonActivated = $false
}
