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
