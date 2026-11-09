# Relocate the per-user Docker Desktop install (default C:) to another drive.
# The original path is replaced by a directory junction, so Shortcuts, the
# docker-desktop:// protocol handler, WSL integration and in-place updates keep
# working with the same path string.
#
# Usage
#   powershell -ExecutionPolicy Bypass -File .\relocate-docker-desktop.ps1
#   powershell -ExecutionPolicy Bypass -File .\relocate-docker-desktop.ps1 -TargetRoot 'G:\Docker\DockerDesktop'
#   powershell -ExecutionPolicy Bypass -File .\relocate-docker-desktop.ps1 -Restore
#
# ASCII-only: Windows PowerShell 5.1 mis-parses BOM-less UTF-8 scripts.

[CmdletBinding()]
param(
    [string]$TargetRoot = 'G:\Docker\DockerDesktop',
    [switch]$Restore,
    [switch]$SkipStart
)

$ErrorActionPreference = 'Stop'
$linkPath = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop'
$dockerCli = Join-Path $linkPath 'resources\bin\docker.exe'

function Get-InstallState {
    $item = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
    if (-not $item) { return 'missing' }
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return 'junction' }
    return 'directory'
}

function Stop-DockerDesktop {
    if (Test-Path -LiteralPath $dockerCli) {
        & $dockerCli desktop stop 2>&1 | Out-Null
    }
    Start-Sleep -Seconds 5
    Get-Process -Name 'Docker Desktop', 'com.docker.backend', 'com.docker.build', 'com.docker.admin' -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host ("waiting for {0} pid={1}" -f $_.Name, $_.Id); $_.WaitForExit(15000) | Out-Null }
}

function Start-DockerDesktop {
    if ($SkipStart) { return }
    if (-not (Test-Path -LiteralPath $dockerCli)) { throw 'docker CLI not found after relocation.' }
    & $dockerCli desktop start 2>&1 | Out-Null
    for ($i = 0; $i -lt 30; $i++) {
        $version = (& $dockerCli version --format '{{.Server.Version}}' 2>&1 | Out-String).Trim()
        if ($version -match '^\d+\.\d+\.') { Write-Host "engine ready: $version"; return }
        Start-Sleep -Seconds 5
    }
    Write-Host 'engine not ready yet; start Docker Desktop manually and check docker desktop status.'
}

$state = Get-InstallState
Write-Host "install path: $linkPath"
Write-Host "state: $state"

if ($Restore) {
    if ($state -ne 'junction') { Write-Host 'nothing to restore'; return }
    Stop-DockerDesktop
    robocopy $TargetRoot $linkPath /E /MOVE /R:1 /W:1 /MT:16 /NFL /NDL /NJH /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with $LASTEXITCODE" }
    Start-DockerDesktop
    Write-Host "restored to $linkPath"
    return
}

if ($state -eq 'junction') {
    $current = (Get-Item -LiteralPath $linkPath -Force).Target
    Write-Host "already relocated to: $current"
    return
}
if ($state -ne 'directory') { throw 'Docker Desktop is not installed at the expected per-user path.' }

Stop-DockerDesktop
New-Item -ItemType Directory -Path (Split-Path -Parent $TargetRoot) -Force | Out-Null
if (Test-Path -LiteralPath $TargetRoot) { throw "$TargetRoot already exists; move or remove it first." }

Write-Host "moving $linkPath -> $TargetRoot"
robocopy $linkPath $TargetRoot /E /MOVE /R:1 /W:1 /MT:16 /NFL /NDL /NJH /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with $LASTEXITCODE" }
if (Test-Path -LiteralPath $linkPath) { throw "$linkPath still exists after move; check for open handles." }

& cmd /c mklink /J "$linkPath" "$TargetRoot" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'mklink failed.' }

$item = Get-Item -LiteralPath $linkPath -Force
Write-Host ("junction: {0} -> {1}" -f $linkPath, $item.Target)
Start-DockerDesktop
Write-Host "done. Docker Desktop binaries now live in $TargetRoot"
