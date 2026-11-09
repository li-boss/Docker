#Requires -RunAsAdministrator
<#
    WSL recovery for Docker Desktop on Windows (ASCII-only on purpose:
    Windows PowerShell 5.1 mis-parses BOM-less UTF-8 scripts).

    Symptoms
      - `wsl -l -v` and `wsl --shutdown` hang with no output and time out
      - Docker Desktop shows "WSL is unresponsive"
      - backend log repeats DockerDesktop/Wsl/CommandTimedOut

    What it does: force-kills the wedged WSL service and VM processes, restarts
    WSLService, then probes the distro list with a timeout. It never touches
    docker_data.vhdx or any distro data.

    Usage
      powershell -ExecutionPolicy Bypass -File G:\GardenerOS\recover-wsl.ps1
#>
[CmdletBinding()]
param(
    [string]$LogPath = (Join-Path $PSScriptRoot 'logs\wsl-recovery.log'),
    [int]$ProbeTimeoutSeconds = 45
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
}

function Test-Elevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Timed {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSeconds)
    $stdout = Join-Path $env:TEMP ([guid]::NewGuid().ToString('N') + '.out')
    $stderr = Join-Path $env:TEMP ([guid]::NewGuid().ToString('N') + '.err')
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) {
        try { $process.Kill() } catch { }
        Write-Log ("TIMEOUT after {0}s: {1} {2}" -f $TimeoutSeconds, $FilePath, ($Arguments -join ' '))
    }
    if (Test-Path -LiteralPath $stdout) {
        Get-Content -LiteralPath $stdout | Where-Object { $_ -ne '' } | ForEach-Object { Write-Log ('out: ' + $_) }
    }
    if (Test-Path -LiteralPath $stderr) {
        Get-Content -LiteralPath $stderr | Where-Object { $_ -ne '' } | ForEach-Object { Write-Log ('err: ' + $_) }
    }
    Remove-Item -LiteralPath $stdout, $stderr -ErrorAction SilentlyContinue
    return $finished
}

Write-Log '--- WSL recovery start ---'
if (-not (Test-Elevated)) {
    Write-Log 'ABORT: administrator rights required. Rerun from an elevated prompt.'
    exit 2
}

Write-Log '1/4 stop WSLService and force-kill wedged WSL processes'
& "$env:SystemRoot\System32\sc.exe" stop WSLService | ForEach-Object { Write-Log ('sc stop: ' + $_) }
Start-Sleep -Seconds 2
Get-Process -Name wslservice, vmmemWSL, wslhost, wslrelay, wsl -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Log ("killing {0} pid={1}" -f $_.Name, $_.Id)
    & "$env:SystemRoot\System32\taskkill.exe" /F /PID $_.Id /T 2>&1 | ForEach-Object { Write-Log ('taskkill: ' + $_) }
}
Start-Sleep -Seconds 4

Write-Log '2/4 start WSLService'
& "$env:SystemRoot\System32\sc.exe" start WSLService | ForEach-Object { Write-Log ('sc start: ' + $_) }
Start-Sleep -Seconds 5
Write-Log ('WSLService status: ' + (Get-Service -Name WSLService).Status)

Write-Log '3/4 shut down leftover WSL virtual machine'
[void](Invoke-Timed -FilePath "$env:SystemRoot\System32\wsl.exe" -Arguments @('--shutdown') -TimeoutSeconds $ProbeTimeoutSeconds)
Start-Sleep -Seconds 3

Write-Log '4/4 probe distro list'
$probeOk = Invoke-Timed -FilePath "$env:SystemRoot\System32\wsl.exe" -Arguments @('-l', '-v') -TimeoutSeconds $ProbeTimeoutSeconds

if ($probeOk) {
    Write-Log 'WSL is responsive again. If docker-desktop is missing from the list, run: docker desktop start'
} else {
    Write-Log 'WSL still unresponsive: reboot Windows, then run: docker desktop start'
}
Write-Log '--- WSL recovery done ---'
