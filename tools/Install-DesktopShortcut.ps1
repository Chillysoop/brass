[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$gameName = 'Brass & Aether.exe'
$project = Split-Path -Parent $PSScriptRoot
$stateDirectory = Join-Path $env:LOCALAPPDATA 'BrassAether'
$localBuild = Join-Path $stateDirectory 'builds/local'
$launcher = Join-Path $stateDirectory 'Launch-BrassAether.ps1'
$desktop = [Environment]::GetFolderPath('DesktopDirectory')
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop -PathType Container)) {
    throw 'The Windows desktop folder could not be located.'
}

$null = New-Item -ItemType Directory -Path $localBuild -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-BrassAether.ps1') -Destination $launcher -Force
$builtGame = Join-Path (Join-Path $project 'build') $gameName
$offlineGame = Join-Path $localBuild $gameName
if ((Test-Path -LiteralPath $builtGame -PathType Leaf) -and
    -not (Test-Path -LiteralPath $offlineGame -PathType Leaf)) {
    Copy-Item -LiteralPath $builtGame -Destination $offlineGame
}

$shortcutPath = Join-Path $desktop 'Brass & Aether.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$shortcut.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File "' + $launcher + '"'
$shortcut.WorkingDirectory = $stateDirectory
$shortcut.Description = 'Play Brass & Aether and check for updates in the background.'
if (Test-Path -LiteralPath $offlineGame -PathType Leaf) {
    $shortcut.IconLocation = $offlineGame + ',0'
}
$shortcut.Save()
Write-Output $shortcutPath
