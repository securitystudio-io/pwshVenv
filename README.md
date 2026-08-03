# pwshVenv

A PowerShell module that wraps Python's `venv` with profile-based configuration. Store named virtual environment settings as JSON files and manage them with idiomatic PowerShell cmdlets.

---

## Features

- **Named profiles** — store venv configuration as JSON files for repeatable, shareable environments
- **Template inheritance** — seed a new profile from an existing one and override individual fields
- **Environment variable management** — define per-venv `$env:` variables applied on activation and restored on exit
- **Post-activate scripts** — run PowerShell scripts automatically when a venv is entered
- **Selective initialization** — skip Python activation, PowerShell init, or both via profile flags or runtime switches
- **Safe session state** — `Exit-Pwshvenv` restores all env vars to their pre-activation values

---

## Requirements

- PowerShell 7.0+
- Python 3.x installed and on `$env:PATH` (or specify a full interpreter path per profile)
- [Pester](https://pester.dev/) 5.x (for running tests)

---

## Installation

### From source

```powershell
git clone https://github.com/securitystudio-io/pwshVenv.git
Import-Module .\pwshVenv\pwshVenv.psd1
```

### From PowerShell Gallery *(coming soon)*

```powershell
Install-Module -Name pwshVenv
```

---

## Quick start

```powershell
# Create a new venv named "myapp" using Python 3.12
New-Pwshvenv -Name myapp -PythonPath python3.12

# List all profiles
Get-Pwshvenv

# Activate
Enter-Pwshvenv -Name myapp

# ... work ...

# Deactivate
Exit-Pwshvenv
```

---

## Profile JSON schema

Profiles are stored as JSON files in the **VenvRoot** directory (`$env:USERPROFILE\.venv\` by default). Each file is named `<name>.json`.

```json
{
  "name": "myapp",
  "pythonPath": "python3.12",
  "requirementsFile": "C:\\Projects\\myapp\\requirements.txt",
  "venvLocation": null,
  "environmentVariables": {
    "DEBUG": "true",
    "DATABASE_URL": "sqlite:///db.sqlite3"
  },
  "postActivateScripts": [
    "C:\\Projects\\myapp\\scripts\\dev-setup.ps1"
  ],
  "skipPythonActivation": false,
  "skipPowershellInit": false
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | string | *(required)* | Profile identifier. Must match the filename. |
| `pythonPath` | string | `"python"` | Interpreter used to create and rebuild the venv. |
| `requirementsFile` | string | `null` | Absolute path to `requirements.txt`. Installed on `New-Pwshvenv` and `Update-Pwshvenv`. |
| `venvLocation` | string | `null` | Custom path for the venv directory. Defaults to `<VenvRoot>\<name>`. |
| `environmentVariables` | object | `{}` | Key-value pairs set in the process environment on activation. |
| `postActivateScripts` | array | `[]` | `.ps1` scripts dot-sourced after activation. |
| `skipPythonActivation` | bool | `false` | When `true`, `Activate.ps1` is not run during `Enter-Pwshvenv`. |
| `skipPowershellInit` | bool | `false` | When `true`, env vars and post-activate scripts are skipped during `Enter-Pwshvenv`. |

---

## Commands

### `New-Pwshvenv`

Creates a new virtual environment and saves its profile.

```powershell
New-Pwshvenv -Name <string>
             [-PythonPath <string>]
             [-RequirementsFile <string>]
             [-VenvLocation <string>]
             [-EnvironmentVariables <hashtable>]
             [-PostActivateScripts <string[]>]
             [-SkipPythonActivation]
             [-SkipPowershellInit]
             [-TemplatePath <string>]
             [-VenvRoot <string>]
```

**Examples**

```powershell
# Minimal — uses default Python and stores venv under $env:USERPROFILE\.venv\myapp
New-Pwshvenv -Name myapp

# Full options
New-Pwshvenv -Name myapp `
             -PythonPath python3.12 `
             -RequirementsFile C:\Projects\myapp\requirements.txt `
             -EnvironmentVariables @{ DEBUG = 'true'; API_KEY = 'dev-key' } `
             -PostActivateScripts @('C:\Projects\myapp\scripts\init.ps1')

# From a template — inherits all fields and overrides PythonPath
New-Pwshvenv -Name myapp-dev -TemplatePath ~\.venv\myapp.json -PythonPath python3.11
```

> **Template precedence:** values in the template are the baseline; any parameter you pass explicitly wins.

---

### `Get-Pwshvenv`

Lists venv profiles stored in the VenvRoot.

```powershell
Get-Pwshvenv [-Name <string>]
             [-VenvRoot <string>]
```

**Examples**

```powershell
# List all profiles
Get-Pwshvenv

# Get a specific profile
Get-Pwshvenv -Name myapp

# Pipe to see the resolved venv path
Get-Pwshvenv | Select-Object Name, VenvLocation
```

**Output properties:** `Name`, `PythonPath`, `RequirementsFile`, `VenvLocation`, `EnvironmentVariables`, `PostActivateScripts`, `SkipPythonActivation`, `SkipPowershellInit`, `ProfilePath`

---

### `Enter-Pwshvenv`

Activates a virtual environment in the current session.

```powershell
Enter-Pwshvenv -Name <string>
               [-VenvRoot <string>]
               [-SkipPythonActivation]
               [-SkipPowershellInit]
```

**What it does (in order):**

1. Dot-sources `<VenvLocation>\Scripts\Activate.ps1` *(unless `skipPythonActivation` is set)*
2. Applies `environmentVariables` from the profile to the current process *(unless `skipPowershellInit` is set)*
3. Dot-sources each `postActivateScripts` entry *(unless `skipPowershellInit` is set)*

**Examples**

```powershell
# Full activation
Enter-Pwshvenv -Name myapp

# Activate the Python venv only — skip env vars and scripts
Enter-Pwshvenv -Name myapp -SkipPowershellInit

# Apply env vars and scripts only — skip Activate.ps1
Enter-Pwshvenv -Name myapp -SkipPythonActivation
```

> Parameters override the corresponding profile JSON flags at runtime without modifying the stored profile.

---

### `Exit-Pwshvenv`

Deactivates the current virtual environment and restores session state.

```powershell
Exit-Pwshvenv
```

**What it does (in order):**

1. Calls `deactivate` *(only if Python activation ran during `Enter-Pwshvenv`)*
2. Restores every environment variable to the value it held before activation

---

### `Update-Pwshvenv`

Rebuilds a virtual environment from its saved profile. Useful after changing Python versions or repairing a broken environment.

```powershell
Update-Pwshvenv -Name <string>
                [-VenvRoot <string>]
```

**What it does (in order):**

1. Loads the existing profile — does **not** modify the JSON
2. Removes the current venv directory
3. Recreates the venv using the interpreter in the profile
4. Reinstalls packages from `requirementsFile` if one is set

```powershell
Update-Pwshvenv -Name myapp
```

> Deactivate the venv with `Exit-Pwshvenv` before running this command to avoid file-lock errors on Windows.

---

## Configuration

### Custom VenvRoot

All commands accept `-VenvRoot` to override the default storage location for a single call:

```powershell
New-Pwshvenv -Name myapp -VenvRoot D:\venvs
Enter-Pwshvenv -Name myapp -VenvRoot D:\venvs
```

---

## Running tests

The test suite uses [Pester](https://pester.dev/) v5. Install it once, then run all tests from the module root:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
Invoke-Pester .\Tests -Output Detailed
```

Tests mock all external processes (`python`, `pip`) and the filesystem under Pester's `$TestDrive`, so no real Python installation is required to run them.

---

## Contributing

1. Fork the repository and create a feature branch.
2. Add or update tests in `Tests\` for any behaviour change.
3. Ensure `Invoke-Pester .\Tests` passes with no failures.
4. Open a pull request with a clear description of the change.

All public functions must include full comment-based help (`Get-Help New-Pwshvenv -Full` should return complete documentation).

---

## License

MIT — see [LICENSE](LICENSE).
