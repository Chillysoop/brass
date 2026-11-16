[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$gameName = 'Brass & Aether.exe'
$project = Split-Path -Parent $PSScriptRoot
$previousState = Join-Path $env:LOCALAPPDATA 'BrassAether'
# A packaged installer host may redirect AppData into its private cache.
$stateDirectory = Join-Path $env:USERPROFILE 'Games/Brass Aether'
$playableGame = Join-Path $stateDirectory $gameName
$launcher = Join-Path $stateDirectory 'Launch-BrassAether.ps1'
$bootstrap = Join-Path $stateDirectory 'BrassAetherLauncher.exe'
$desktop = [Environment]::GetFolderPath('DesktopDirectory')
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop -PathType Container)) {
    throw 'The Windows desktop folder could not be located.'
}

function Find-LegacyGame([string] $Directory) {
    foreach ($markerName in @('current-build.txt', 'current-build.previous')) {
        $marker = Join-Path $Directory $markerName
        if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { continue }
        $revision = ([string](Get-Content -LiteralPath $marker -Raw)).Trim()
        if ($revision -notmatch '^[0-9a-f]{40}$') { continue }
        $candidate = Join-Path $Directory "builds/$revision/$gameName"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return @{ Path = $candidate; Revision = $revision }
        }
    }
}

function Initialize-PlayableGame {
    $existingLocal = Join-Path $stateDirectory "builds/local/$gameName"
    if ((Test-Path -LiteralPath $playableGame -PathType Leaf) -or (Find-LegacyGame $stateDirectory) -or
        (Test-Path -LiteralPath $existingLocal -PathType Leaf)) { return }

    $seed = Find-LegacyGame $previousState
    if (-not $seed) {
        $builtGame = Join-Path $project "build/$gameName"
        foreach ($candidate in @($builtGame, (Join-Path $previousState "builds/local/$gameName"))) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $seed = @{ Path = $candidate; Revision = '' }
                break
            }
        }
    }
    if (-not $seed) { return }

    $stagedGame = Join-Path $stateDirectory ('Game-' + [guid]::NewGuid().ToString('N') + '.pending')
    try {
        Copy-Item -LiteralPath $seed.Path -Destination $stagedGame
        $marker = Join-Path $stateDirectory 'current-build.txt'
        if ($seed.Revision) {
            Set-Content -LiteralPath $marker -Value $seed.Revision -Encoding ascii
        } elseif (Test-Path -LiteralPath $marker -PathType Leaf) {
            Remove-Item -LiteralPath $marker -Force
        }
        [IO.File]::Move($stagedGame, $playableGame)
    } finally {
        if (Test-Path -LiteralPath $stagedGame -PathType Leaf) { Remove-Item -LiteralPath $stagedGame -Force }
    }
}

$null = New-Item -ItemType Directory -Path $stateDirectory -Force
$updateLock = [IO.File]::Open((Join-Path $stateDirectory 'update.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    Initialize-PlayableGame
} finally {
    $updateLock.Dispose()
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
$shortcut.Description = 'Check for updates and play Brass & Aether.'
$shortcut.WindowStyle = 1
$iconSource = if (Test-Path -LiteralPath $playableGame -PathType Leaf) { $playableGame } else { $bootstrap }
$shortcut.IconLocation = $iconSource + ',0'
$shortcut.Save()
Write-Output $shortcutPath
