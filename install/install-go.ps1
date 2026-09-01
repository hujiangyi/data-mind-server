[CmdletBinding()]
param(
    [string]$Version = "latest",
    [string]$ReleaseBase = "",
    [string]$GiteeReleaseBase = "https://gitee.com/hujiangyi/data-mind-server/releases/download",
    [ValidateSet("auto", "github", "gitee")][string]$ReleaseSource = "auto",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "DataMind"),
    [string]$CloudApiBase = "https://dm.iter-self.top/v1",
    [string]$McpSetupBaseUrl = "",
    [string]$McpPublicApiBase = "",
    [switch]$ForceKey,
    [switch]$SkipChecksum
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw $Message
}

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "缺少命令：$Name"
    }
}

function Invoke-Download([string]$Uri, [string]$OutFile) {
    $parameters = @{
        Uri = $Uri
        OutFile = $OutFile
        UseBasicParsing = $true
    }
    Invoke-WebRequest @parameters
    if (-not (Test-Path -LiteralPath $OutFile) -or (Get-Item -LiteralPath $OutFile).Length -eq 0) {
        Fail "下载文件为空：$Uri"
    }
}

function Get-EnvValue([string]$Path, [string]$Name) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    $pattern = "^$([regex]::Escape($Name))=(.*)$"
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match $pattern) {
            return $Matches[1]
        }
    }
    return ""
}

function Read-SecretValue([string]$Prompt) {
    $secure = Read-Host $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function New-MasterKey() {
    $bytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $random.GetBytes($bytes)
    }
    finally {
        $random.Dispose()
    }
    return "MKEY:$([Convert]::ToBase64String($bytes))"
}

function Get-ReleaseRoot([string]$Base, [string]$ReleaseVersion) {
    $baseRoot = $Base.TrimEnd("/")
    if ($ReleaseVersion -eq "latest" -and $baseRoot.EndsWith("/download")) {
        return "$($baseRoot.Substring(0, $baseRoot.Length - 8))/latest/download"
    }
    return "$baseRoot/$ReleaseVersion"
}

function Test-ReleaseSource([string]$Base, [string]$ReleaseVersion) {
    try {
        $root = Get-ReleaseRoot $Base $ReleaseVersion
        Invoke-WebRequest -Uri "$root/checksums.txt" -UseBasicParsing -TimeoutSec 12 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Select-ReleaseBase() {
    if ([string]::IsNullOrWhiteSpace($ReleaseBase) -and $env:DATAMIND_RELEASE_BASE) {
        $script:ReleaseBase = $env:DATAMIND_RELEASE_BASE
    }
    if ([string]::IsNullOrWhiteSpace($ReleaseBase)) {
        switch ($ReleaseSource) {
            "github" { $script:ReleaseBase = "https://github.com/hujiangyi/data-mind-server/releases/download" }
            "gitee" { $script:ReleaseBase = $GiteeReleaseBase }
            "auto" {
                foreach ($candidate in @(
                    @{ Name = "gitee"; Base = $GiteeReleaseBase },
                    @{ Name = "github"; Base = "https://github.com/hujiangyi/data-mind-server/releases/download" }
                )) {
                    if (Test-ReleaseSource $candidate.Base $Version) {
                        $script:ReleaseBase = $candidate.Base
                        Write-Host "自动选择 Release 源：$($candidate.Name) ($($candidate.Base))"
                        return
                    }
                }
                Fail "Gitee 和 GitHub Release 源均不可达；请设置 DATAMIND_RELEASE_BASE 指定镜像地址"
            }
        }
    }
    Write-Host "使用 Release 源：$ReleaseBase"
}

Assert-Command "docker"

$dockerOs = (& docker info --format '{{.OSType}}' 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $dockerOs -ne "linux") {
    Fail "Docker Desktop 不可用或未运行 Linux Containers，请先启动 Docker Desktop 并切换到 Linux 容器模式"
}

& docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "当前 Docker 没有可用的 docker compose 子命令"
}

$processorArchitecture = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
} else {
    $env:PROCESSOR_ARCHITECTURE
}

switch ($processorArchitecture.ToUpperInvariant()) {
    "AMD64" {
        $dockerArch = "amd64"
        $dockerPlatform = "linux/amd64"
    }
    "ARM64" {
        $dockerArch = "arm64"
        $dockerPlatform = "linux/arm64"
    }
    default {
        Fail "不支持的 Windows 主机架构：$processorArchitecture"
    }
}

if ($CloudApiBase -notmatch "^https?://\S+$") {
    Fail "-CloudApiBase 必须是 HTTP 或 HTTPS 地址"
}

Select-ReleaseBase

$temporaryRoot = Join-Path $env:TEMP "datamind-go-$([guid]::NewGuid().ToString('N'))"
$archivePath = Join-Path $temporaryRoot "bundle.zip"
$extractRoot = Join-Path $temporaryRoot "extract"
New-Item -ItemType Directory -Force -Path $temporaryRoot, $extractRoot | Out-Null

try {
    $releaseRoot = Get-ReleaseRoot $ReleaseBase $Version
    $asset = "datamind-docker-linux-$dockerArch.zip"
    Invoke-Download "$releaseRoot/$asset" $archivePath

    if (-not $SkipChecksum) {
        $checksumPath = Join-Path $temporaryRoot "checksums.txt"
        Invoke-Download "$releaseRoot/checksums.txt" $checksumPath
        $line = Get-Content -LiteralPath $checksumPath |
            Where-Object { $_ -match "^\s*[a-fA-F0-9]{64}\s+$([regex]::Escape($asset))\s*$" } |
            Select-Object -First 1
        if (-not $line) {
            Fail "checksums.txt 中没有找到 $asset"
        }
        $expected = ($line -split "\s+")[0].ToLowerInvariant()
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            Fail "校验失败：$asset"
        }
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
    $composeFile = Get-ChildItem -LiteralPath $extractRoot -Filter "docker-compose.yml" -Recurse |
        Select-Object -First 1
    if (-not $composeFile) {
        Fail "Docker 分发包缺少 docker-compose.yml"
    }
    $bundleRoot = $composeFile.Directory.FullName
    foreach ($required in @("Dockerfile.runtime", "bin\daas-go", "configs\config.yaml", "migrations")) {
        if (-not (Test-Path -LiteralPath (Join-Path $bundleRoot $required))) {
            Fail "Docker 分发包缺少：$required"
        }
    }

    New-Item -ItemType Directory -Force -Path $InstallDir, (Join-Path $InstallDir "data") | Out-Null
    Copy-Item -LiteralPath (Join-Path $bundleRoot "docker-compose.yml") -Destination $InstallDir -Force
    Copy-Item -LiteralPath (Join-Path $bundleRoot "Dockerfile.runtime") -Destination $InstallDir -Force
    Copy-Item -LiteralPath (Join-Path $bundleRoot ".env.example") -Destination $InstallDir -Force
    Copy-Item -LiteralPath (Join-Path $bundleRoot "bin") -Destination $InstallDir -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $bundleRoot "migrations") -Destination $InstallDir -Recurse -Force
    if (-not (Test-Path -LiteralPath (Join-Path $InstallDir "configs\config.yaml"))) {
        Copy-Item -LiteralPath (Join-Path $bundleRoot "configs") -Destination $InstallDir -Recurse -Force
    }

    $envPath = Join-Path $InstallDir ".env"
    $cloudApiKey = Get-EnvValue $envPath "DATAMIND_CLOUD_API_KEY"
    if ($ForceKey -or [string]::IsNullOrWhiteSpace($cloudApiKey)) {
        $cloudApiKey = Read-SecretValue "请输入 DataMind API Key"
    }
    if ([string]::IsNullOrWhiteSpace($cloudApiKey) -or $cloudApiKey.Contains("`r") -or $cloudApiKey.Contains("`n")) {
        Fail "DataMind API Key 不能为空，且不能包含换行"
    }

    $masterKey = Get-EnvValue $envPath "DAAS_MCP_MASTER_KEY"
    if ([string]::IsNullOrWhiteSpace($masterKey)) {
        $masterKey = New-MasterKey
    }

    if ([string]::IsNullOrWhiteSpace($McpSetupBaseUrl)) {
        $McpSetupBaseUrl = Get-EnvValue $envPath "DAAS_MCP_SETUP_BASE_URL"
    }
    if ([string]::IsNullOrWhiteSpace($McpPublicApiBase)) {
        $McpPublicApiBase = Get-EnvValue $envPath "DAAS_MCP_PUBLIC_API_BASE"
    }
    if ([string]::IsNullOrWhiteSpace($McpSetupBaseUrl) -and -not [string]::IsNullOrWhiteSpace($McpPublicApiBase)) {
        $McpSetupBaseUrl = $McpPublicApiBase
    }
    if ([string]::IsNullOrWhiteSpace($McpPublicApiBase) -and -not [string]::IsNullOrWhiteSpace($McpSetupBaseUrl)) {
        $McpPublicApiBase = $McpSetupBaseUrl
    }
    if ([string]::IsNullOrWhiteSpace($McpSetupBaseUrl)) {
        $McpSetupBaseUrl = "http://127.0.0.1:3001"
    }
    if ([string]::IsNullOrWhiteSpace($McpPublicApiBase)) {
        $McpPublicApiBase = $McpSetupBaseUrl
    }
    if ($McpSetupBaseUrl -notmatch "^https?://\S+$") {
        Fail "-McpSetupBaseUrl 必须是 HTTP 或 HTTPS 地址"
    }
    if ($McpPublicApiBase -notmatch "^https?://\S+$") {
        Fail "-McpPublicApiBase 必须是 HTTP 或 HTTPS 地址"
    }

    $lines = @(
        "DATAMIND_DOCKER_PLATFORM=$dockerPlatform"
        "DATAMIND_BIND_ADDRESS=$(if (Get-EnvValue $envPath 'DATAMIND_BIND_ADDRESS') { Get-EnvValue $envPath 'DATAMIND_BIND_ADDRESS' } else { '127.0.0.1' })"
        "DATAMIND_PORT=$(if (Get-EnvValue $envPath 'DATAMIND_PORT') { Get-EnvValue $envPath 'DATAMIND_PORT' } else { '3001' })"
        "DATAMIND_CLOUD_API_BASE=$CloudApiBase"
        "DATAMIND_CLOUD_API_KEY=$cloudApiKey"
        "DAAS_MCP_MASTER_KEY=$masterKey"
        "DAAS_MCP_SETUP_BASE_URL=$McpSetupBaseUrl"
        "DAAS_MCP_PUBLIC_API_BASE=$McpPublicApiBase"
    )
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($envPath, $lines, $utf8)

    Push-Location $InstallDir
    try {
        & docker compose --project-name datamind --project-directory $InstallDir up -d --build
        if ($LASTEXITCODE -ne 0) {
            Fail "Docker Compose 启动失败"
        }
    }
    finally {
        Pop-Location
    }

    $port = Get-EnvValue $envPath "DATAMIND_PORT"
    if ([string]::IsNullOrWhiteSpace($port)) {
        $port = "3001"
    }
    $healthy = $false
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                $healthy = $true
                break
            }
        }
        catch {
            Start-Sleep -Seconds 2
        }
    }
    if (-not $healthy) {
        & docker compose --project-name datamind --project-directory $InstallDir logs --tail 80
        Fail "DataMind Go 服务健康检查失败：http://127.0.0.1:$port/health"
    }

    Write-Host "DataMind Go Docker 服务已启动"
    Write-Host "安装目录：$InstallDir"
    Write-Host "访问地址：http://127.0.0.1:$port"
    Write-Host "Docker 架构：$dockerPlatform"
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
