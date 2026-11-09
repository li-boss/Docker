
<#
    Docker Desktop sign-in hand-off repair (Windows).

    Symptom
      Docker Desktop -> Sign in opens login.docker.com in the browser. After
      authorizing, the page stays on "You're almost done!" and the button
      "Proceed to Docker Desktop" does nothing, so the app never signs in.

    Cause
      The browser hands the authorization code back with the docker-desktop://
      URL scheme. HKCU\Software\Classes\docker-desktop is not registered on this
      machine (a quiet per-user install can skip it), so the click is dropped.

    This script registers the scheme with the install's default form:
      "<install path>\Docker Desktop.exe" "%1"

    Usage
      powershell -ExecutionPolicy Bypass -File .\fix-docker-signin.ps1
      powershell -ExecutionPolicy Bypass -File .\fix-docker-signin.ps1 -Verify
      powershell -ExecutionPolicy Bypass -File .\fix-docker-signin.ps1 -Unregister

    ASCII-only on purpose: Windows PowerShell 5.1 mis-parses UTF-8 files
    without a BOM.
#>
[CmdletBinding()]
param(
    [switch]$Unregister,
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$protocol = 'docker-desktop'
$classRoot = "HKCU:\Software\Classes\$protocol"

function Resolve-DockerDesktopExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw 'Docker Desktop.exe not found. Install and start Docker Desktop first.'
}

if ($Unregister) {
    if (Test-Path -LiteralPath $classRoot) {
        Remove-Item -LiteralPath $classRoot -Recurse -Force
        Write-Host "Removed: $classRoot"
    } else {
        Write-Host "Not registered: $classRoot"
    }
    return
}

$exe = Resolve-DockerDesktopExe
Write-Host "Docker Desktop: $exe"

New-Item -Path "$classRoot\shell\open\command" -Force | Out-Null
New-Item -Path "$classRoot\DefaultIcon" -Force | Out-Null
Set-ItemProperty -Path $classRoot -Name '(default)' -Value "URL:$protocol"
New-ItemProperty -Path $classRoot -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
Set-ItemProperty -Path "$classRoot\DefaultIcon" -Name '(default)' -Value ('"' + $exe + '",0')
$command = '"' + $exe + '" "%1"'
Set-ItemProperty -Path "$classRoot\shell\open\command" -Name '(default)' -Value $command

$registered = (Get-ItemProperty -Path "$classRoot\shell\open\command").'(default)'
$hasProtocolFlag = (Get-ItemProperty -Path $classRoot).'URL Protocol' -eq ''
Write-Host "Key: $classRoot"
Write-Host "Command: $registered"
if ($hasProtocolFlag) {
    Write-Host 'URL Protocol marker: set'
} else {
    Write-Host 'URL Protocol marker: missing'
}

if (-not $Verify) { return }

# Self-test: the launcher logs "show-dashboard flag detected" when it parses a
# docker-desktop:// URL from the command line.
$log = "$env:LOCALAPPDATA\Docker\log\host\com.docker.backend.exe.log"
if (-not (Test-Path -LiteralPath $log)) {
    Write-Host 'Backend log not found; start Docker Desktop once and rerun with -Verify.'
    return
}
$before = (Get-Content -LiteralPath $log).Count
Start-Process "${protocol}://dashboard/open"
Start-Sleep -Seconds 8
$after = Get-Content -LiteralPath $log
$new = if ($after.Count -gt $before) { $after[$before..($after.Count - 1)] } else { @() }
if ($new -match 'show-dashboard flag detected') {
    Write-Host 'Self-test passed: the protocol URL reached and was parsed by Docker Desktop.'
} else {
    Write-Host 'Self-test missed the show-dashboard marker; retry Sign in from Docker Desktop.'
}
