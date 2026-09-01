#!/usr/bin/env bash
set -Eeuo pipefail

export LC_ALL=C
export LC_CTYPE=C
export LANG=C

VERSION="${DATAMIND_GO_VERSION:-latest}"
GITHUB_RELEASE_BASE="${DATAMIND_GITHUB_RELEASE_BASE:-https://github.com/hujiangyi/data-mind-server/releases/download}"
GITEE_RELEASE_BASE="${DATAMIND_GITEE_RELEASE_BASE:-https://gitee.com/hujiangyi/data-mind-server/releases/download}"
RELEASE_BASE="${DATAMIND_RELEASE_BASE:-}"
RELEASE_SOURCE="${DATAMIND_RELEASE_SOURCE:-auto}"
INSTALL_DIR="${DATAMIND_GO_INSTALL_DIR:-/opt/datamind-go}"
SERVICE_NAME="${DATAMIND_GO_SERVICE_NAME:-datamind-go}"
CLOUD_API_BASE="${DATAMIND_CLOUD_API_BASE:-https://dm.iter-self.top/v1}"
API_KEY="${DATAMIND_CLOUD_API_KEY:-}"
MCP_MASTER_KEY="${DAAS_MCP_MASTER_KEY:-}"
MCP_SETUP_BASE_URL="${DAAS_MCP_SETUP_BASE_URL:-}"
MCP_PUBLIC_API_BASE="${DAAS_MCP_PUBLIC_API_BASE:-}"

fail() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令：$1"
}

read_env_value() {
  local file="$1"
  local name="$2"
  [[ -f "$file" ]] || return 0
  awk -v name="$name" 'index($0, name "=") == 1 {sub(/^[^=]*=/, ""); value=$0} END {print value}' "$file"
}

release_root_for() {
  local base="${1%/}"
  if [[ "$VERSION" == "latest" && "$base" == */download ]]; then
    printf '%s/latest/download\n' "${base%/download}"
  else
    printf '%s/%s\n' "$base" "$VERSION"
  fi
}

release_root() {
  release_root_for "$RELEASE_BASE"
}

probe_release() {
  local base="$1"
  local root
  root="$(release_root_for "$base")"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error --location --ipv4 --http1.1 \
      --retry 2 --retry-delay 1 --connect-timeout 5 --max-time 15 \
      -o /dev/null "$root/checksums.txt"
  else
    wget --quiet --timeout=5 --tries=2 -O /dev/null "$root/checksums.txt"
  fi
}

select_release_base() {
  if [[ -n "$RELEASE_BASE" ]]; then
    printf '使用指定 Release 源：%s\n' "$RELEASE_BASE"
    return 0
  fi

  local source
  local candidate
  case "$RELEASE_SOURCE" in
    github)
      RELEASE_BASE="$GITHUB_RELEASE_BASE"
      ;;
    gitee)
      RELEASE_BASE="$GITEE_RELEASE_BASE"
      ;;
    auto)
      for source in gitee github; do
        if [[ "$source" == "gitee" ]]; then
          candidate="$GITEE_RELEASE_BASE"
        else
          candidate="$GITHUB_RELEASE_BASE"
        fi
        if probe_release "$candidate" >/dev/null 2>&1; then
          RELEASE_BASE="$candidate"
          printf '自动选择 Release 源：%s (%s)\n' "$source" "$RELEASE_BASE"
          return 0
        fi
      done
      fail "Gitee 和 GitHub Release 源均不可达；可设置 DATAMIND_RELEASE_BASE 指定镜像地址"
      ;;
    *)
      fail "DATAMIND_RELEASE_SOURCE 必须是 auto、github 或 gitee"
      ;;
  esac
  printf '使用 Release 源：%s\n' "$RELEASE_BASE"
}

download() {
  local url="$1"
  local destination="$2"
  if command -v curl >/dev/null 2>&1; then
    if [[ "$url" == *.tar.gz ]]; then
      download_ranges_with_curl "$url" "$destination"
    else
      curl --fail --silent --show-error --location --ipv4 --http1.1 \
        --retry 6 --retry-delay 3 --retry-connrefused --retry-all-errors \
        --connect-timeout 15 --max-time 120 -o "$destination" "$url"
    fi
  else
    wget --quiet --timeout=30 --tries=6 --waitretry=3 -c -O "$destination" "$url"
  fi
  [[ -s "$destination" ]] || fail "下载文件为空：$url"
}

download_ranges_with_curl() {
  local url="$1"
  local destination="$2"
  local headers="$destination.headers"
  local probe="$destination.probe"
  local part="$destination.part"
  local total
  local offset
  local end
  local expected_size
  local actual_size
  local chunk_size=$((1024 * 1024))

  curl --fail --silent --show-error --location --ipv4 --http1.1 \
    --retry 6 --retry-delay 3 --retry-connrefused --retry-all-errors \
    --connect-timeout 15 --max-time 90 \
    --range 0-0 -D "$headers" -o "$probe" "$url"
  total="$(sed -nE 's/^[Cc]ontent-[Rr]ange:[[:space:]]+bytes[[:space:]]+[0-9]+-[0-9]+\/([0-9]+).*$/\1/p' "$headers" | tail -1)"
  if [[ ! "$total" =~ ^[0-9]+$ ]]; then
    if [[ -s "$probe" ]]; then
      mv "$probe" "$destination"
      rm -f "$headers"
      return 0
    fi
    rm -f "$headers" "$probe"
    fail "无法从 Release 获取文件大小：$url"
  fi
  rm -f "$headers" "$probe"

  if [[ -f "$destination" ]]; then
    actual_size="$(wc -c < "$destination" | tr -d ' ')"
    if [[ "$actual_size" -gt "$total" ]]; then
      : > "$destination"
      actual_size=0
    fi
  else
    : > "$destination"
    actual_size=0
  fi
  offset="$actual_size"

  while [[ "$offset" -lt "$total" ]]; do
    end=$((offset + chunk_size - 1))
    if [[ "$end" -ge "$total" ]]; then
      end=$((total - 1))
    fi
    expected_size=$((end - offset + 1))
    printf '下载分段：%s-%s/%s\n' "$offset" "$end" "$total"
    curl --fail --silent --show-error --location --ipv4 --http1.1 \
      --retry 6 --retry-delay 3 --retry-connrefused --retry-all-errors \
      --connect-timeout 15 --max-time 90 \
      --range "$offset-$end" -o "$part" "$url"
    actual_size="$(wc -c < "$part" | tr -d ' ')"
    [[ "$actual_size" -eq "$expected_size" ]] || {
      rm -f "$part"
      fail "Release 分段大小异常：期望 $expected_size，实际 $actual_size"
    }
    cat "$part" >> "$destination"
    rm -f "$part"
    offset=$((end + 1))
  done
}

verify_checksum() {
  local file="$1"
  local asset="$2"
  local checksum_file="$3"
  local expected
  local actual

  expected="$(awk -v asset="$asset" '$2 == asset || $2 == "*" asset {print $1; exit}' "$checksum_file")"
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || fail "checksums.txt 中没有找到：$asset"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  fi
  [[ "${actual,,}" == "${expected,,}" ]] || fail "校验失败：$asset"
}

validate_secret() {
  local name="$1"
  local value="$2"
  [[ -n "$value" ]] || fail "$name 不能为空"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail "$name 不能包含换行"
}

[[ "$EUID" -eq 0 ]] || fail "Linux Go 服务需要 root 权限，请使用 sudo 或 root 执行"
[[ "$CLOUD_API_BASE" =~ ^https?://[^[:space:]]+$ ]] || fail "DATAMIND_CLOUD_API_BASE 必须是 HTTP 或 HTTPS 地址"

require_command tar
require_command awk
require_command systemctl
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  fail "缺少 curl 或 wget"
fi
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  fail "缺少 sha256sum 或 shasum"
fi

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) fail "不支持的 Linux 架构：$(uname -m)" ;;
esac

ASSET="datamind-go-linux-$ARCH.tar.gz"
select_release_base

ENV_FILE="$INSTALL_DIR/.env"
if [[ -z "$API_KEY" ]]; then
  API_KEY="$(read_env_value "$ENV_FILE" "DATAMIND_CLOUD_API_KEY")"
fi
if [[ -z "$API_KEY" ]]; then
  if [[ -r /dev/tty ]]; then
    read -r -s -p "请输入 DataMind API Key： " API_KEY < /dev/tty
    printf '\n'
  else
    fail "未提供 DataMind API Key，请设置 DATAMIND_CLOUD_API_KEY 后重试"
  fi
fi
validate_secret "DataMind API Key" "$API_KEY"

if [[ -z "$MCP_SETUP_BASE_URL" ]]; then
  MCP_SETUP_BASE_URL="$(read_env_value "$ENV_FILE" "DAAS_MCP_SETUP_BASE_URL")"
fi
if [[ -z "$MCP_PUBLIC_API_BASE" ]]; then
  MCP_PUBLIC_API_BASE="$(read_env_value "$ENV_FILE" "DAAS_MCP_PUBLIC_API_BASE")"
fi
if [[ -z "$MCP_SETUP_BASE_URL" && -n "$MCP_PUBLIC_API_BASE" ]]; then
  MCP_SETUP_BASE_URL="$MCP_PUBLIC_API_BASE"
fi
if [[ -z "$MCP_PUBLIC_API_BASE" && -n "$MCP_SETUP_BASE_URL" ]]; then
  MCP_PUBLIC_API_BASE="$MCP_SETUP_BASE_URL"
fi
MCP_SETUP_BASE_URL="${MCP_SETUP_BASE_URL:-http://127.0.0.1:3001}"
MCP_PUBLIC_API_BASE="${MCP_PUBLIC_API_BASE:-$MCP_SETUP_BASE_URL}"
[[ "$MCP_SETUP_BASE_URL" =~ ^https?://[^[:space:]]+$ ]] ||
  fail "DAAS_MCP_SETUP_BASE_URL 必须是 HTTP 或 HTTPS 地址"
[[ "$MCP_PUBLIC_API_BASE" =~ ^https?://[^[:space:]]+$ ]] ||
  fail "DAAS_MCP_PUBLIC_API_BASE 必须是 HTTP 或 HTTPS 地址"

if [[ -z "$MCP_MASTER_KEY" ]]; then
  MCP_MASTER_KEY="$(read_env_value "$ENV_FILE" "DAAS_MCP_MASTER_KEY")"
fi
if [[ -z "$MCP_MASTER_KEY" ]]; then
  require_command openssl
  MCP_MASTER_KEY="MKEY:$(openssl rand -base64 32 | tr -d '\n')"
fi
validate_secret "DAAS_MCP_MASTER_KEY" "$MCP_MASTER_KEY"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/datamind-go-install.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

RELEASE_ROOT="$(release_root)"
ARCHIVE="$TMP_ROOT/$ASSET"
CHECKSUMS="$TMP_ROOT/checksums.txt"
EXTRACT_ROOT="$TMP_ROOT/extract"

printf '下载 DataMind Go %s（Linux %s）\n' "$VERSION" "$ARCH"
download "$RELEASE_ROOT/$ASSET" "$ARCHIVE"
download "$RELEASE_ROOT/checksums.txt" "$CHECKSUMS"
verify_checksum "$ARCHIVE" "$ASSET" "$CHECKSUMS"

mkdir -p "$EXTRACT_ROOT"
tar -xzf "$ARCHIVE" -C "$EXTRACT_ROOT"
[[ -x "$EXTRACT_ROOT/bin/daas-go" ]] || fail "Release 缺少 bin/daas-go"
[[ -f "$EXTRACT_ROOT/configs/config.yaml" ]] || fail "Release 缺少 configs/config.yaml"
[[ -d "$EXTRACT_ROOT/migrations" ]] || fail "Release 缺少 migrations 目录"

mkdir -p "$INSTALL_DIR"
if [[ ! -f "$INSTALL_DIR/configs/config.yaml" ]]; then
  mkdir -p "$INSTALL_DIR/configs"
  cp "$EXTRACT_ROOT/configs/config.yaml" "$INSTALL_DIR/configs/config.yaml"
fi
rm -rf "$INSTALL_DIR/bin" "$INSTALL_DIR/migrations"
cp -R "$EXTRACT_ROOT/bin" "$INSTALL_DIR/bin"
cp -R "$EXTRACT_ROOT/migrations" "$INSTALL_DIR/migrations"
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp"
printf '%s\n' "$VERSION" > "$INSTALL_DIR/VERSION"
chmod 0755 "$INSTALL_DIR/bin/daas-go"

if ! id -u datamind >/dev/null 2>&1; then
  useradd --system --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin datamind
fi

umask 077
ENV_TMP="$TMP_ROOT/.env"
{
  printf 'DATAMIND_CLOUD_API_BASE=%s\n' "$CLOUD_API_BASE"
  printf 'DATAMIND_CLOUD_API_KEY=%s\n' "$API_KEY"
  printf 'DAAS_MCP_MASTER_KEY=%s\n' "$MCP_MASTER_KEY"
  printf 'DAAS_MCP_SETUP_BASE_URL=%s\n' "$MCP_SETUP_BASE_URL"
  printf 'DAAS_MCP_PUBLIC_API_BASE=%s\n' "$MCP_PUBLIC_API_BASE"
} > "$ENV_TMP"
install -m 0600 "$ENV_TMP" "$ENV_FILE"

chown -R datamind:datamind "$INSTALL_DIR"
chmod 0750 "$INSTALL_DIR"
chmod 0600 "$ENV_FILE"

cat > "/etc/systemd/system/$SERVICE_NAME.service" <<UNIT
[Unit]
Description=DataMind Go Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=datamind
Group=datamind
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$INSTALL_DIR/bin/daas-go -config $INSTALL_DIR/configs/config.yaml
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME.service"

for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error http://127.0.0.1:3001/health >/dev/null; then
    printf 'DataMind Go 安装成功\n'
    printf '安装目录：%s\n' "$INSTALL_DIR"
    printf '服务名称：%s.service\n' "$SERVICE_NAME"
    printf '服务地址：http://127.0.0.1:3001\n'
    printf '状态检查：systemctl status %s.service\n' "$SERVICE_NAME"
    exit 0
  fi
  sleep 2
done

systemctl --no-pager --full status "$SERVICE_NAME.service" || true
journalctl --no-pager -u "$SERVICE_NAME.service" -n 100 || true
fail "DataMind Go 健康检查失败：http://127.0.0.1:3001/health"
