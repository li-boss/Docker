#Requires -RunAsAdministrator
<#
    WSL 无响应恢复脚本（Windows / Docker Desktop）

    症状：
      - `wsl -l -v`、`wsl --shutdown` 长时间无输出并超时；
      - Docker Desktop 弹出 “WSL is unresponsive”；
      - 后端日志出现 DockerDesktop/Wsl/CommandTimedOut。

    用法（必须提权；普通窗口执行会直接退出）：
      powershell -ExecutionPolicy Bypass -File G:\GardenerOS\recover-wsl.ps1
      或 start powershell -Verb RunAs ...

    脚本只做三件事：强杀卡死的 WSL 服务与 VM 进程、重新启动服务、带超时探测发行版列表。
    它不改动任何发行版数据，也不删除 docker_data.vhdx。
#>
[CmdletBinding()]
param(
    [string]$LogPath = (Join-Path $PSScriptRoot 'logs\wsl-recovery.log'),
    [int]$ProbeTimeoutSeconds = 45
)

$ErrorActionPreference = 'Continue'
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $PSScriptRoot) { $LogPath = Join-Path $ScriptDir 'logs\wsl-recovery.log' }
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
        Get-Content -LiteralPath $stdout | Where-Object { $_ -ne '' } | ForEach-Object { Write-Log ("out: " + $_) }
    }
    if (Test-Path -LiteralPath $stderr) {
        Get-Content -LiteralPath $stderr | Where-Object { $_ -ne '' } | ForEach-Object { Write-Log ("err: " + $_) }
    }
    Remove-Item -LiteralPath $stdout, $stderr -ErrorAction SilentlyContinue
    return $finished
}

Write-Log '--- WSL recovery start ---'
if (-not (Test-Elevated)) {
    Write-Log 'ABORT：需要管理员权限。请以管理员身份重新运行本脚本。'
    exit 2
}

Write-Log '1/4 停止 WSLService 并强杀卡死的 WSL 进程'
& "$env:SystemRoot\System32\sc.exe" stop WSLService | ForEach-Object { Write-Log ("sc stop: " + $_) }
Start-Sleep -Seconds 2
Get-Process -Name wslservice, vmmemWSL, wslhost, wslrelay, wsl -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Log ("killing {0} pid={1}" -f $_.Name, $_.Id)
    & "$env:SystemRoot\System32\taskkill.exe" /F /PID $_.Id /T 2>&1 | ForEach-Object { Write-Log ("taskkill: " + $_) }
}
Start-Sleep -Seconds 4

Write-Log '2/4 启动 WSLService'
& "$env:SystemRoot\System32\sc.exe" start WSLService | ForEach-Object { Write-Log ("sc start: " + $_) }
Start-Sleep -Seconds 5
Write-Log ("WSLService 状态: " + (Get-Service -Name WSLService).Status)

Write-Log '3/4 关闭残留 WSL 虚拟机'
[void](Invoke-Timed -FilePath "$env:SystemRoot\System32\wsl.exe" -Arguments @('--shutdown') -TimeoutSeconds $ProbeTimeoutSeconds)
Start-Sleep -Seconds 3

Write-Log '4/4 探测发行版列表'
$probeOk = Invoke-Timed -FilePath "$env:SystemRoot\System32\wsl.exe" -Arguments @('-l', '-v') -TimeoutSeconds $ProbeTimeoutSeconds

if ($probeOk) {
    Write-Log 'WSL 已恢复。若 docker-desktop 发行版未列出，执行：docker desktop start'
} else {
    Write-Log 'WSL 仍未响应：请重启 Windows 后再运行 docker desktop start'
}
Write-Log '--- WSL recovery done ---'
