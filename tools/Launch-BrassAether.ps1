[CmdletBinding()]
param(
    [switch] $CheckOnly,
    [string] $Repository = 'https://github.com/Chillysoop/brass.git',
    [string] $StateDirectory = (Join-Path $env:USERPROFILE 'Games/Brass Aether'),
    [string] $Godot = (Join-Path $env:LOCALAPPDATA 'BrassAetherTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe')
)

$ErrorActionPreference = 'Stop'
$gameName = 'Brass & Aether.exe'
$builds = Join-Path $StateDirectory 'builds'
$executable = Join-Path $StateDirectory $gameName
$marker = Join-Path $StateDirectory 'current-build.txt'
$previousMarker = Join-Path $StateDirectory 'current-build.previous'
$activity = Join-Path $StateDirectory 'launcher.log'
$cache = Join-Path $StateDirectory 'repository.git'
$installedGodot = Join-Path $StateDirectory 'tools/Godot_v4.7.2-stable_win64.exe'
$installedTemplate = Join-Path $StateDirectory 'tools/windows_release_x86_64.exe'
if (-not $PSBoundParameters.ContainsKey('Godot') -and (Test-Path -LiteralPath $installedGodot -PathType Leaf)) {
    $Godot = $installedGodot
}

function Invoke-LauncherCommand {
    param([string] $Name, [string] $Program, [string[]] $Arguments, [int] $Seconds)

    $stdout = Join-Path $StateDirectory "$Name.stdout.log"
    $stderr = Join-Path $StateDirectory "$Name.stderr.log"
    $argumentLine = ($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $process = Start-Process -FilePath $Program -ArgumentList $argumentLine -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    try {
        # Keep the native handle alive so Windows PowerShell can read short-lived process exit codes.
        $null = $process.Handle
        if (-not $process.WaitForExit($Seconds * 1000)) {
            & "$env:SystemRoot/System32/taskkill.exe" /PID $process.Id /T /F *> $null
            throw "$Name exceeded its $Seconds second timeout."
        }
        if ($process.ExitCode -ne 0) {
            $detail = Get-Content -LiteralPath $stderr -Tail 4
            throw "$Name exited with code $($process.ExitCode). $($detail -join ' ')"
        }
        return (Get-Content -LiteralPath $stdout -Raw)
    } finally {
        $process.Dispose()
    }
}

function Read-BuildRevision([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $version = ([string](Get-Content -LiteralPath $Path -Raw)).Trim()
    if ($version -cmatch '^[0-9a-f]{40}$') { return $version }
}

function Find-LegacyBuilds {
    foreach ($versionFile in @($marker, $previousMarker)) {
        $version = Read-BuildRevision $versionFile
        if (-not $version) { continue }
        $candidate = Join-Path (Join-Path $builds $version) $gameName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            [pscustomobject]@{ Path = $candidate; Revision = $version }
        }
    }
    $fallback = Join-Path (Join-Path $builds 'local') $gameName
    if (Test-Path -LiteralPath $fallback -PathType Leaf) {
        [pscustomobject]@{ Path = $fallback; Revision = $null }
    }
}

function Find-PlayableBuilds {
    if (Test-Path -LiteralPath $executable -PathType Leaf) { return $executable }
    Find-LegacyBuilds | Select-Object -ExpandProperty Path
}

function Save-BuildRevision([string] $Version) {
    if (-not $Version) {
        if (Test-Path -LiteralPath $marker -PathType Leaf) { Remove-Item -LiteralPath $marker }
        return
    }
    if ((Read-BuildRevision $marker) -eq $Version) { return }
    $pending = Join-Path $StateDirectory 'current-build.pending'
    Set-Content -LiteralPath $pending -Value $Version -Encoding ascii
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        [IO.File]::Replace($pending, $marker, [NullString]::Value)
    } else {
        [IO.File]::Move($pending, $marker)
    }
}

function Import-LegacyBuild {
    if (Test-Path -LiteralPath $executable -PathType Leaf) { return }
    $legacy = Find-LegacyBuilds | Select-Object -First 1
    if (-not $legacy) { return }
    $pending = Join-Path $StateDirectory ('migrate-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::Copy($legacy.Path, $pending)
        Save-BuildRevision $legacy.Revision
        [IO.File]::Move($pending, $executable)
        Add-Content -LiteralPath $activity -Value "Migrated $($legacy.Path) to $executable."
    } finally {
        if (Test-Path -LiteralPath $pending -PathType Leaf) { Remove-Item -LiteralPath $pending }
    }
}

function Remove-LegacyBuilds {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf) -or
        -not (Test-Path -LiteralPath $builds -PathType Container)) { return }
    $buildRoot = Get-Item -LiteralPath $builds
    if ($buildRoot.Attributes -band [IO.FileAttributes]::ReparsePoint) { return }
    $processName = [IO.Path]::GetFileNameWithoutExtension($gameName)
    $runningGames = @(Get-Process -Name $processName -ErrorAction SilentlyContinue | ForEach-Object Path)
    foreach ($folder in (Get-ChildItem -LiteralPath $buildRoot.FullName -Directory)) {
        if ($folder.Name -cnotmatch '^(local|[0-9a-f]{40})$' -or
            ($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $folder.Parent.FullName -ne $buildRoot.FullName) { continue }
        $legacyGame = Join-Path $folder.FullName $gameName
        if ($legacyGame -in $runningGames -or -not (Test-Path -LiteralPath $legacyGame -PathType Leaf)) { continue }
        try {
            Remove-Item -LiteralPath $legacyGame -Force
            if (-not (Get-ChildItem -LiteralPath $folder.FullName -Force | Select-Object -First 1)) {
                [IO.Directory]::Delete($folder.FullName)
            }
        } catch {
            Add-Content -LiteralPath $activity -Value "Could not remove $legacyGame. $($_.Exception.Message)"
        }
    }
}

function Update-PlayableBuild {
    $git = (Get-Command git.exe -CommandType Application | Select-Object -First 1).Source
    if (-not (Test-Path -LiteralPath (Join-Path $cache 'HEAD') -PathType Leaf)) {
        $null = Invoke-LauncherCommand 'git-init' $git @('init', '--bare', $cache) 8
    }
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'never'
    $gitOptions = @('--git-dir', $cache)
    $branch = 'refs/remotes/origin/main'
    $fetch = @('-c', 'http.version=HTTP/1.1', '-c', 'http.lowSpeedLimit=1', '-c', 'http.lowSpeedTime=20', 'fetch',
        '--depth=1', '--no-tags', $Repository, "+refs/heads/main:$branch")
    $null = Invoke-LauncherCommand 'git-fetch' $git ($gitOptions + $fetch) 90
    $version = (Invoke-LauncherCommand 'git-version' $git ($gitOptions + @('rev-parse', '--verify', $branch)) 8).Trim()
    if ($version -notmatch '^[0-9a-f]{40}$') { throw 'Git returned an invalid revision.' }

    if ((Test-Path -LiteralPath $executable -PathType Leaf) -and (Read-BuildRevision $marker) -eq $version) {
        Add-Content -LiteralPath $activity -Value "Already installed $version."
    } else {
        if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw "Godot was not found at $Godot." }
        $stage = Join-Path $StateDirectory 'staging'
        $work = Join-Path $stage ([guid]::NewGuid().ToString('N'))
        $source = Join-Path $work 'source'
        $export = Join-Path $work 'export'
        $archive = Join-Path $work 'source.zip'
        $null = New-Item -ItemType Directory -Path $work, $source, $export -Force
        try {
            $gitArchive = @('archive', '--format=zip', "--output=$archive", $version)
            $null = Invoke-LauncherCommand 'git-archive' $git ($gitOptions + $gitArchive) 20
            Expand-Archive -LiteralPath $archive -DestinationPath $source
            if (Test-Path -LiteralPath $installedTemplate -PathType Leaf) {
                $presets = Join-Path $source 'export_presets.cfg'
                $template = $installedTemplate.Replace('\', '/')
                $config = (Get-Content -LiteralPath $presets -Raw).Replace('[preset.0.options]', "[preset.0.options]`ncustom_template/release=`"$template`"")
                [IO.File]::WriteAllText($presets, $config)
            }
            $importLog = Join-Path $StateDirectory 'godot-import.log'
            $exportLog = Join-Path $StateDirectory 'godot-export.log'
            $smokeLog = Join-Path $StateDirectory 'godot-smoke.log'
            $null = Invoke-LauncherCommand 'import' $Godot @(
                '--headless', '--path', $source, '--editor', '--import', '--log-file', $importLog
            ) 90
            $stagedGame = Join-Path $export $gameName
            $null = Invoke-LauncherCommand 'export' $Godot @(
                '--headless', '--path', $source, '--export-release', 'Windows Desktop', $stagedGame,
                '--log-file', $exportLog
            ) 90
            if (-not (Test-Path -LiteralPath $stagedGame -PathType Leaf)) { throw 'Godot did not produce a Windows executable.' }
            $null = Invoke-LauncherCommand 'smoke' $stagedGame @('--headless', '--quit-after', '5', '--log-file', $smokeLog) 20
            foreach ($log in @($importLog, $exportLog, $smokeLog)) {
                if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet) {
                    throw "Godot reported an error in $log."
                }
            }
            if (Test-Path -LiteralPath $executable -PathType Leaf) {
                [IO.File]::Replace($stagedGame, $executable, [NullString]::Value)
            } else {
                [IO.File]::Move($stagedGame, $executable)
            }
            Save-BuildRevision $version
        } finally {
            $resolvedStage = (Resolve-Path -LiteralPath $stage).Path
            $resolvedWork = (Resolve-Path -LiteralPath $work).Path
            if ([IO.Path]::GetDirectoryName($resolvedWork) -eq $resolvedStage) {
                Remove-Item -LiteralPath $resolvedWork -Recurse -Force
            }
        }
        Add-Content -LiteralPath $activity -Value "Installed $version."
    }
    return $executable
}

function Start-PlayableBuild([string[]] $Candidates) {
    $launchLockPath = Join-Path $StateDirectory 'launch.lock'
    try {
        $launchLock = [IO.File]::Open($launchLockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    } catch [IO.IOException] {
        return $true
    }
    try {
        $processName = [IO.Path]::GetFileNameWithoutExtension($gameName)
        $startupLog = Join-Path $StateDirectory 'startup.log'
        $existing = Get-Process -Name $processName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existing) {
            $null = (New-Object -ComObject WScript.Shell).AppActivate($existing.Id)
            return $true
        }
        foreach ($candidate in ($Candidates | Select-Object -Unique)) {
            try {
                $gameProcess = Start-Process -FilePath $candidate -WorkingDirectory (Split-Path -Parent $candidate) -WindowStyle Normal -PassThru
                try {
                    if (-not $gameProcess.WaitForExit(900)) {
                        Set-Content -LiteralPath $startupLog -Value "$(Get-Date -Format o) Started $candidate"
                        return $true
                    }
                    $reason = "Game closed during startup (exit code $($gameProcess.ExitCode))."
                } finally {
                    $gameProcess.Dispose()
                }
            } catch {
                $reason = $_.Exception.Message
            }
            Add-Content -LiteralPath $startupLog -Value "$(Get-Date -Format o) $candidate - $reason"
        }
        return $false
    } finally {
        $launchLock.Dispose()
    }
}

function Invoke-UpdateCheck {
    $lockPath = Join-Path $StateDirectory 'update.lock'
    try {
        $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    } catch [IO.IOException] {
        if ($CheckOnly) { throw 'Another Brass & Aether launch is already checking for updates.' }
        return
    }
    try {
        Set-Content -LiteralPath $activity -Value ('Update check ' + (Get-Date -Format o))
        try {
            Import-LegacyBuild
        } catch {
            Add-Content -LiteralPath $activity -Value ('Could not migrate the existing build. ' + $_.Exception.Message)
        }
        try {
            $playable = Update-PlayableBuild
        } catch {
            Add-Content -LiteralPath $activity -Value ('Update unavailable. ' + $_.Exception.Message)
            $playable = Find-PlayableBuilds | Select-Object -First 1
        }
        try {
            Remove-LegacyBuilds
        } catch {
            Add-Content -LiteralPath $activity -Value ('Could not finish old build cleanup. ' + $_.Exception.Message)
        }
        if ($playable) { Add-Content -LiteralPath $activity -Value "Playable: $playable" }
        return $playable
    } finally {
        $lock.Dispose()
    }
}

$null = New-Item -ItemType Directory -Path $StateDirectory -Force
if ($CheckOnly) {
    $playable = Invoke-UpdateCheck
    if (-not $playable) { throw "No playable build was found. Details are in $activity" }
    Write-Output $playable
    return
}

$null = Invoke-UpdateCheck
$candidates = @(Find-PlayableBuilds)
$started = $candidates.Count -gt 0 -and (Start-PlayableBuild $candidates)
if (-not $started) {
    $message = "Brass & Aether could not open. Launcher logs are in $StateDirectory."
    $null = (New-Object -ComObject WScript.Shell).Popup($message, 0, 'Brass & Aether', 16)
    exit 1
}
