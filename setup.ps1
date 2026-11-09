[CmdletBinding()]
param(
    [string]$ContainerName = 'gardeneros-dev',
    [string]$ImageName = 'myopeneuler',
    [string]$Author = '',
    [int]$BuildJobs = 4,
    [switch]$SaveOnly
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($BuildJobs -lt 1) { throw 'BuildJobs must be positive.' }
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCommand) {
    $dockerExe = $dockerCommand.Source
} else {
    $dockerExe = @(
        "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe",
        "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (!$dockerExe) { throw 'Install and start Docker Desktop before running setup.ps1.' }
}
$env:PATH = (Split-Path -Parent $dockerExe) + [IO.Path]::PathSeparator + $env:PATH
function Invoke-Docker {
    & $dockerExe @args
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed with exit code $LASTEXITCODE" }
}
Invoke-Docker info --format '{{.OSType}}'
$existing = & $dockerExe container ls -a --filter "name=^/$ContainerName`$" --format '{{.Names}}'
if ($LASTEXITCODE -ne 0) { throw 'Unable to list Docker containers.' }
if ($existing) {
    $mounts = & $dockerExe inspect $ContainerName --format '{{json .Mounts}}' | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing container.' }
    $expected = [IO.Path]::GetFullPath($PSScriptRoot).Replace('\','/').ToLowerInvariant()
    $matches = @($mounts | Where-Object {
        $_.Destination -eq '/mnt' -and $_.Type -eq 'bind' -and
        $_.Source.Replace('\','/').ToLowerInvariant() -eq $expected
    })
    if ($matches.Count -ne 1) { throw 'Existing container uses a different /mnt mount; choose another ContainerName.' }
    Invoke-Docker start $ContainerName
} else {
    if ($SaveOnly) { throw 'The configured container does not exist; run full setup first.' }
    Invoke-Docker run -dit --name $ContainerName --mount "type=bind,source=$PSScriptRoot,destination=/mnt" --workdir /mnt openeuler/openeuler bash
}
if (!$SaveOnly) {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'logs') -Force | Out-Null
    $logPath = Join-Path $PSScriptRoot ('logs/setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
    $previousPreference = $ErrorActionPreference
    try {
        # Merge installer stderr inside the container for Windows PowerShell 5.
        $ErrorActionPreference = 'Continue'
        & $dockerExe exec -e "BUILD_JOBS=$BuildJobs" $ContainerName bash -c 'exec bash /mnt/setup-container.sh 2>&1' 2>&1 | Tee-Object -FilePath $logPath
        $setupExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($setupExitCode -ne 0) { throw "Environment setup failed. See $logPath" }
}
Invoke-Docker exec $ContainerName bash /mnt/verify-container.sh
$commitArgs = @('commit', '--pause=false', '-m', 'New configured environment')
if ($Author) { $commitArgs += @('-a', $Author) }
$commitArgs += @($ContainerName, $ImageName)
Invoke-Docker @commitArgs
Invoke-Docker run --rm --mount "type=bind,source=$PSScriptRoot,destination=/mnt" --workdir /mnt $ImageName bash /mnt/verify-container.sh
Write-Host "Image created: $ImageName"
Write-Host "Enter container: docker exec -it $ContainerName bash"
