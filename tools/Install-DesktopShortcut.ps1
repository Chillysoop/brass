[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$gameName = 'Brass & Aether.exe'
$project = Split-Path -Parent $PSScriptRoot
$previousState = Join-Path $env:LOCALAPPDATA 'BrassAether'
# A packaged installer host may redirect AppData into its private cache.
$stateDirectory = Join-Path $env:USERPROFILE 'Games/Brass Aether'
$localBuild = Join-Path $stateDirectory 'builds/local'
$launcher = Join-Path $stateDirectory 'Launch-BrassAether.ps1'
$bootstrap = Join-Path $stateDirectory 'BrassAetherLauncher.exe'
$desktop = [Environment]::GetFolderPath('DesktopDirectory')
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop -PathType Container)) {
    throw 'The Windows desktop folder could not be located.'
}

$null = New-Item -ItemType Directory -Path $localBuild -Force
$builtGame = Join-Path (Join-Path $project 'build') $gameName
$offlineGame = Join-Path $localBuild $gameName
foreach ($markerName in @('current-build.txt', 'current-build.previous')) {
    $oldMarker = Join-Path $previousState $markerName
    $newMarker = Join-Path $stateDirectory $markerName
    if ((Test-Path -LiteralPath $newMarker) -or -not (Test-Path -LiteralPath $oldMarker)) { continue }
    $revision = (Get-Content -LiteralPath $oldMarker -Raw).Trim()
    if ($revision -notmatch '^[0-9a-f]{40}$') { continue }
    $oldBuild = Join-Path $previousState "builds/$revision/$gameName"
    if (-not (Test-Path -LiteralPath $oldBuild -PathType Leaf)) { continue }
    $newBuild = Join-Path $stateDirectory "builds/$revision"
    $null = New-Item -ItemType Directory -Path $newBuild -Force
    Copy-Item -LiteralPath $oldBuild -Destination $newBuild
    Set-Content -LiteralPath $newMarker -Value $revision -Encoding ascii
}
if (-not (Test-Path -LiteralPath $offlineGame -PathType Leaf)) {
    foreach ($candidate in @($builtGame, (Join-Path $previousState "builds/local/$gameName"))) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        Copy-Item -LiteralPath $candidate -Destination $offlineGame
        break
    }
}

$toolDirectory = Join-Path $stateDirectory 'tools'
$installedGodot = Join-Path $toolDirectory 'Godot_v4.7.2-stable_win64.exe'
$installedTemplate = Join-Path $toolDirectory 'windows_release_x86_64.exe'
$godotSource = Join-Path $env:LOCALAPPDATA 'BrassAetherTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe'
$templateSource = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
$null = New-Item -ItemType Directory -Path $toolDirectory -Force
if (-not (Test-Path -LiteralPath $installedGodot) -and (Test-Path -LiteralPath $godotSource)) {
    Copy-Item -LiteralPath $godotSource -Destination $installedGodot
}
if (-not (Test-Path -LiteralPath $installedTemplate) -and (Test-Path -LiteralPath $templateSource)) {
    Copy-Item -LiteralPath $templateSource -Destination $installedTemplate
}

$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
$bootstrapSource = Join-Path $PSScriptRoot 'BrassAetherLauncher.cs'
$stagedBootstrap = Join-Path $stateDirectory ('Launcher-' + [guid]::NewGuid().ToString('N') + '.exe')
try {
    & $compiler /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/out:$stagedBootstrap" $bootstrapSource
    if ($LASTEXITCODE -ne 0) { throw 'Could not compile the Brass & Aether launcher.' }
    if (Test-Path -LiteralPath $bootstrap -PathType Leaf) {
        [IO.File]::Replace($stagedBootstrap, $bootstrap, [NullString]::Value)
    } else {
        [IO.File]::Move($stagedBootstrap, $bootstrap)
    }
} finally {
    if (Test-Path -LiteralPath $stagedBootstrap -PathType Leaf) { Remove-Item -LiteralPath $stagedBootstrap -Force }
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-BrassAether.ps1') -Destination $launcher -Force

$shortcutPath = Join-Path $desktop 'Brass & Aether.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $bootstrap
$shortcut.Arguments = ''
$shortcut.WorkingDirectory = $stateDirectory
$shortcut.Description = 'Play Brass & Aether and check for updates in the background.'
$shortcut.WindowStyle = 1
if (Test-Path -LiteralPath $offlineGame -PathType Leaf) {
    $shortcut.IconLocation = $offlineGame + ',0'
}
$shortcut.Save()
Write-Output $shortcutPath
