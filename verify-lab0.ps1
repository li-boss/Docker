# Lab 0 (environment setup) verification for the GardenerOS course.
# Prints one numbered block per requirement of the lab sheet, each with PASS or
# FAIL, so a single screen capture covers the whole checklist.
#
# Usage
#   powershell -ExecutionPolicy Bypass -File G:\GardenerOS\verify-lab0.ps1
#
# ASCII-only on purpose: Windows PowerShell 5.1 mis-parses BOM-less UTF-8.

[CmdletBinding()]
param(
    [string]$Container = 'gardeneros-dev',
    [string]$ImageName = 'myopeneuler',
    [string]$RepoPath = 'G:\GardenerOS',
    [switch]$Brief
)

$ErrorActionPreference = 'Continue'

function Get-DockerCli {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe",
        "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"
    )
    foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
    $cmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'docker CLI not found.'
}

$docker = Get-DockerCli
$script:pass = 0
$script:fail = 0
$script:index = 0
$script:total = 14

function Show-Block {
    param([string]$Title, [string]$Body, [bool]$Ok)
    $script:index++
    $state = if ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ''
    Write-Host ('[{0}/{1}] {2}' -f $script:index, $script:total, $Title)
    if ($Body -and -not $Brief) {
        foreach ($line in ($Body -split "`r?`n")) {
            if ($line.Trim()) { Write-Host ('    ' + $line.TrimEnd()) }
        }
    }
    if ($Ok) { $script:pass++ } else { $script:fail++ }
    $color = if ($Ok) { 'Green' } else { 'Red' }
    Write-Host ('    -> ' + $state) -ForegroundColor $color
}

function Invoke-Docker {
    param([string[]]$Arguments)
    return (& $docker @Arguments 2>&1 | Out-String).Trim()
}

function Invoke-Container {
    param([string]$Command)
    return (& $docker exec $Container bash -lc $Command 2>&1 | Out-String).Trim()
}

Write-Host '============================================================'
Write-Host (' Lab 0 environment check   ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Host '============================================================'

# 1. docker engine
$serverVersion = Invoke-Docker @('version', '--format', '{{.Server.Version}}')
$engineOk = $serverVersion -match '^\d+\.\d+\.'
Show-Block 'Docker engine responds' ("server " + $serverVersion) $engineOk
if (-not $engineOk) {
    Write-Host 'Docker Desktop is not running. Start it with: docker desktop start' -ForegroundColor Yellow
    Write-Host ''
    Write-Host ('RESULT: ' + $script:pass + ' passed, ' + $script:fail + ' failed (aborted)') -ForegroundColor Red
    exit 1
}

# 2. base image
$images = Invoke-Docker @('images', '--format', '{{.Repository}}:{{.Tag}}')
Show-Block 'openEuler base image was pulled' (($images -split "`n" | Where-Object { $_ -like 'openeuler/openeuler*' }) -join ', ') ($images -match 'openeuler/openeuler')

# 3. container exists and runs
$containerState = Invoke-Docker @('ps', '-a', '--filter', "name=^/$Container$", '--format', '{{.Names}} {{.Image}} {{.Status}}')
if ($containerState -match $Container) {
    if ($containerState -notmatch 'Up ') { Invoke-Docker @('start', $Container) | Out-Null; Start-Sleep -Seconds 4; $containerState = Invoke-Docker @('ps', '-a', '--filter', "name=^/$Container$", '--format', '{{.Names}} {{.Image}} {{.Status}}') }
}
Show-Block 'Lab container exists and is running' $containerState ($containerState -match 'Up ')

# 4. bind mount /mnt
$mount = Invoke-Docker @('inspect', $Container, '--format', '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{end}}')
$mountOk = ($mount -match '/mnt') -and ($mount -match 'G:')
Show-Block 'Host lab directory is bind-mounted at /mnt' $mount $mountOk

# 5. rust-toolchain pin, host and container view
$hostPin = (Get-Content -LiteralPath (Join-Path $RepoPath 'rust-toolchain') -ErrorAction SilentlyContinue | Select-Object -First 1)
$containerPin = Invoke-Container 'cat /mnt/rust-toolchain'
$pinOk = ($hostPin -eq 'nightly-2026-05-08') -and ($containerPin -eq 'nightly-2026-05-08')
Show-Block 'rust-toolchain pins nightly-2026-05-08 (host and /mnt)' ("host: " + $hostPin + " | container: " + $containerPin) $pinOk

# 6. toolchains installed, nightly is default, pin is active
$rustupShow = Invoke-Container 'source /root/.cargo/env; rustup show'
$tcOk = ($rustupShow -match 'nightly-x86_64-unknown-linux-gnu \(default\)') -and
        ($rustupShow -match 'nightly-2026-05-08-x86_64-unknown-linux-gnu \(active\)') -and
        ($rustupShow -match "overridden by '/mnt/rust-toolchain'")
Show-Block 'nightly installed, set as default, fixed version active' $rustupShow $tcOk

# 7. compiler versions
$versions = Invoke-Container 'source /root/.cargo/env; rustc --version; cargo --version'
Show-Block 'rustc and cargo are nightly builds' $versions (($versions -match 'rustc 1\.\d+\.\d+-nightly') -and ($versions -match 'cargo 1\.\d+\.\d+-nightly'))

# 8. riscv target, llvm-tools, rust-src
$targets = Invoke-Container 'source /root/.cargo/env; rustup target list --installed'
$components = Invoke-Container 'source /root/.cargo/env; rustup component list --installed'
$targetOk = ($targets -match 'riscv64gc-unknown-none-elf') -and ($components -match 'llvm-tools') -and ($components -match 'rust-src')
Show-Block 'riscv64gc-unknown-none-elf target, llvm-tools, rust-src' ($targets + "`n" + $components) $targetOk

# 9. cargo-binutils
$objdump = Invoke-Container 'source /root/.cargo/env; cargo objdump --version'
Show-Block 'cargo-binutils installed' $objdump ($objdump -match 'cargo-objdump')

# 10. cargo registry mirror
$cargoConfig = Invoke-Container 'cat /root/.cargo/config.toml'
Show-Block 'cargo registry mirror configured' $cargoConfig ($cargoConfig -match 'mirrors\.ustc\.edu\.cn')

# 11. rustup mirror variables in .bashrc
$bashrc = Invoke-Container 'grep -n RUSTUP_DIST_SERVER /root/.bashrc; grep -n RUSTUP_UPDATE_ROOT /root/.bashrc'
$mirrorOk = ($bashrc -match 'RUSTUP_DIST_SERVER') -and ($bashrc -match 'RUSTUP_UPDATE_ROOT')
Show-Block '.bashrc exports the rustup mirrors' $bashrc $mirrorOk

# 12. dnf packages and Development Tools group
$packages = Invoke-Container 'rpm -q curl vim-enhanced gcc git; dnf group list --installed 2>/dev/null | grep -i "Development Tools"'
$pkgOk = ($packages -match 'curl-') -and ($packages -match 'vim-enhanced-') -and ($packages -match 'gcc-') -and ($packages -match 'Development Tools')
Show-Block 'curl / vim / gcc plus Development Tools group' $packages $pkgOk

# 13. qemu
$qemu = Invoke-Container 'qemu-system-riscv64 --version | head -n 1; qemu-riscv64 --version | head -n 1'
$qemuOk = (($qemu | Select-String -Pattern 'version 11\.0\.0' -AllMatches).Matches.Count -ge 2)
Show-Block 'QEMU 11.0.0 built and installed' $qemu $qemuOk

# 14. saved image with the author field
$imageInfo = Invoke-Docker @('image', 'inspect', $ImageName, '--format', 'Id={{.Id}} Author={{.Author}} Size={{.Size}}')
$imageOk = ($imageInfo -match 'Author=Di Zhang') -and ($imageInfo -match 'Id=sha256:')
Show-Block 'Docker image committed with author' $imageInfo $imageOk

Write-Host ''
Write-Host '============================================================'
$color = if ($script:fail -eq 0) { 'Green' } else { 'Red' }
Write-Host (' RESULT: ' + $script:pass + ' passed, ' + $script:fail + ' failed') -ForegroundColor $color
Write-Host '============================================================'
if ($script:fail -ne 0) { exit 1 }
