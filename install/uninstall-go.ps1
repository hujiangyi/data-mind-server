[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "DataMind"),
    [switch]$PurgeData
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "缺少命令：docker"
}

if (Test-Path -LiteralPath (Join-Path $InstallDir "docker-compose.yml")) {
    & docker compose --project-name datamind --project-directory $InstallDir down --remove-orphans
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose 停止失败"
    }
}

if ($PurgeData) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "data" } |
        Remove-Item -Recurse -Force
    Write-Host "已停止 DataMind Go Docker 服务，数据目录已保留：$InstallDir\data"
}
