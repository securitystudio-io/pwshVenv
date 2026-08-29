# Dot-source private helpers first so they are available to public functions.
$privateFiles = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $privateFiles) {
    . $file.FullName
}

# Dot-source public functions.
$publicFiles = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    . $file.FullName
}

# Register dynamic tab completion
Register-PwshvenvArgumentCompleters

# Set convenience aliases
Set-Alias -Name 'workon' -Value 'Enter-Pwshvenv' -Description 'pwshVenv: Activate virtual environment' -ErrorAction SilentlyContinue
Set-Alias -Name 'deactivate-venv' -Value 'Exit-Pwshvenv' -Description 'pwshVenv: Deactivate virtual environment' -ErrorAction SilentlyContinue
Set-Alias -Name 'venvs' -Value 'Select-Pwshvenv' -Description 'pwshVenv: Search and select virtual environment' -ErrorAction SilentlyContinue
