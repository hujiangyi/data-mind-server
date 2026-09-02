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
CURL_EXTRA_ARGS=()
if [[ -n "${DATAMIND_CURL_PROXY:-}" ]]; then
  CURL_EXTRA_ARGS+=(--proxy "$DATAMIND_CURL_PROXY")
elif [[ "${DATAMIND_CURL_NO_PROXY:-0}" == "1" ]]; then
  CURL_EXTRA_ARGS+=(--noproxy '*')
fi

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
  printf '检查 Release 源：%s ... ' "$base"
  if command -v curl >/dev/null 2>&1; then
    if curl --fail --silent --location --ipv4 --http1.1 \
        "${CURL_EXTRA_ARGS[@]}" \
        --connect-timeout 4 --max-time 8 \
        -o /dev/null "$root/checksums.txt" 2>/dev/null; then
      printf '可用\n'
      return 0
    fi
  else
    if wget --quiet --timeout=5 --tries=1 -O /dev/null "$root/checksums.txt"; then
      printf '可用\n'
      return 0
    fi
  fi
  printf '不可用\n' >&2
  return 1
}

check_cloud_network() {
  local endpoint="${CLOUD_API_BASE%/}/"
  local status

  printf '安装前检查 Cloud AI 网络连接：%s ... ' "$CLOUD_API_BASE"
  if command -v curl >/dev/null 2>&1; then
    if status="$(curl --silent --show-error --location --ipv4 --http1.1 \
        "${CURL_EXTRA_ARGS[@]}" \
        --connect-timeout 3 --max-time 8 \
        -o /dev/null -w '%{http_code}' "$endpoint" 2>/dev/null)" &&
        [[ "$status" != "000" ]]; then
      printf '可达（HTTP %s）\n' "$status"
      return 0
    fi
    if [[ -z "${DATAMIND_CURL_PROXY:-}" && "${DATAMIND_CURL_NO_PROXY:-0}" != "1" ]]; then
      printf '默认路径失败，尝试直连 ... '
      if status="$(curl --silent --show-error --location --ipv4 --http1.1 \
          --noproxy '*' \
          --connect-timeout 3 --max-time 8 \
          -o /dev/null -w '%{http_code}' "$endpoint" 2>/dev/null)" &&
          [[ "$status" != "000" ]]; then
        CURL_EXTRA_ARGS+=(--noproxy '*')
        printf '成功（HTTP %s）\n' "$status"
        return 0
      fi
    fi
    printf '失败\n' >&2
    printf '提示：如需直连可设置 DATAMIND_CURL_NO_PROXY=1；如需代理可设置 DATAMIND_CURL_PROXY。\n' >&2
    fail "无法连接 Cloud AI，请先检查 DNS、HTTPS、防火墙或代理设置"
  fi

  if wget --quiet --timeout=5 --tries=1 -O /dev/null "$endpoint"; then
    printf '可达\n'
    return 0
  fi
  printf '失败\n' >&2
  fail "无法连接 Cloud AI，请先检查 DNS、HTTPS、防火墙或代理设置"
}

select_release_base() {
  if [[ -n "$RELEASE_BASE" ]]; then
    if ! probe_release "$RELEASE_BASE"; then
      fail "指定的 Release 源不可达：$RELEASE_BASE"
    fi
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
        if probe_release "$candidate"; then
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
  if ! probe_release "$RELEASE_BASE"; then
    fail "指定的 Release 源不可达：$RELEASE_BASE"
  fi
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
        "${CURL_EXTRA_ARGS[@]}" \
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
    "${CURL_EXTRA_ARGS[@]}" \
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
      "${CURL_EXTRA_ARGS[@]}" \
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

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

json_data_value() {
  local file="$1"
  local field="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg field "$field" '.data[$field] // empty' "$file" 2>/dev/null || true
  else
    sed -nE 's/.*"'"$field"'":[[:space:]]*"([^"]*)".*/\1/p' "$file" | head -1
  fi
}

json_error_value() {
  local file="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.error // empty' "$file" 2>/dev/null || true
  else
    sed -nE 's/.*"error":[[:space:]]*"([^"]*)".*/\1/p' "$file" | head -1
  fi
}

register_free_cloud_key() {
  local email
  local password
  local confirmation
  local payload
  local response_file
  local status
  local error_code
  local registered_key
  local key_kind
  local register_url="${CLOUD_API_BASE%/}/cloud/auth/register"

  command -v curl >/dev/null 2>&1 || {
    printf '当前系统没有 curl，无法自动注册；请选择手工输入已有 DataMind API Key。\n' >&2
    return 1
  }
  [[ -r /dev/tty ]] || {
    printf '当前安装不是交互终端，无法收集注册信息。\n' >&2
    return 1
  }

  printf '\nDataMind Cloud 注册只需要一个真实邮箱和至少 8 位密码。\n'
  printf '邮箱用于账号登录和后续账号管理，请确认邮箱可以正常收信。\n'
  read -r -p '注册邮箱： ' email < /dev/tty || return 1
  if [[ ! "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    printf '邮箱格式不正确，请重新输入。\n' >&2
    return 1
  fi

  read -r -s -p '设置 Cloud 登录密码（至少 8 位）： ' password < /dev/tty || return 1
  printf '\n'
  read -r -s -p '确认 Cloud 登录密码： ' confirmation < /dev/tty || return 1
  printf '\n'
  if [[ "${#password}" -lt 8 ]]; then
    printf '密码至少需要 8 位，请重新注册。\n' >&2
    return 1
  fi
  if [[ "$password" != "$confirmation" ]]; then
    printf '两次密码不一致，请重新注册。\n' >&2
    return 1
  fi

  payload="$(printf '{"email":"%s","password":"%s"}' "$(json_escape "$email")" "$(json_escape "$password")")"
  response_file="$(mktemp "${TMPDIR:-/tmp}/datamind-cloud-register.XXXXXX")"
  if ! status="$(printf '%s' "$payload" | curl --silent --show-error --location --ipv4 --http1.1 \
      "${CURL_EXTRA_ARGS[@]}" \
      --retry 2 --retry-delay 1 --connect-timeout 10 --max-time 30 \
      -H 'content-type: application/json' \
      --data-binary @- -o "$response_file" -w '%{http_code}' "$register_url")"; then
    rm -f "$response_file"
    printf '无法连接 DataMind Cloud 注册服务，请检查网络或稍后重试。\n' >&2
    return 1
  fi

  registered_key="$(json_data_value "$response_file" key)"
  key_kind="$(json_data_value "$response_file" keyKind)"
  error_code="$(json_error_value "$response_file")"
  rm -f "$response_file"

  case "$status" in
    200|201)
      if [[ "$registered_key" != dm_free_* ]]; then
        printf 'Cloud 注册响应中没有有效的免费 API Key，请稍后重试。\n' >&2
        return 1
      fi
      API_KEY="$registered_key"
      printf 'Cloud 账号注册成功，已获取免费 DataMind API Key（%s）。\n' "${key_kind:-free}"
      return 0
      ;;
    400)
      printf 'Cloud 注册资料无效（%s），请检查邮箱和密码后重试。\n' "${error_code:-invalid_request}" >&2
      return 1
      ;;
    409)
      printf '该邮箱已经注册，请换一个邮箱，或返回菜单输入已有 API Key。\n' >&2
      return 1
      ;;
    *)
      printf 'Cloud 注册失败（HTTP %s，%s），请稍后重试或输入已有 API Key。\n' \
        "$status" "${error_code:-request_failed}" >&2
      return 1
      ;;
  esac
}

read_existing_cloud_key() {
  local entered_key
  read -r -s -p '请输入 DataMind API Key： ' entered_key < /dev/tty || return 1
  printf '\n'
  API_KEY="$entered_key"
}

obtain_cloud_api_key() {
  local choice

  if [[ -n "$API_KEY" ]]; then
    return 0
  fi
  if [[ ! -r /dev/tty ]]; then
    fail "未提供 DataMind API Key。请执行交互式安装，或设置 DATAMIND_CLOUD_API_KEY 后重试"
  fi

  while true; do
    printf '\n未检测到 DataMind Cloud API Key。\n'
    printf 'DataMind Server 需要该 Key 访问 Cloud AI；请勿输入其他服务的内部密钥。\n'
    printf '请选择操作：\n'
    printf '  1) 自动注册免费账号并生成 Key（推荐）\n'
    printf '  2) 输入已有 DataMind API Key\n'
    printf '  3) 退出安装\n'
    read -r -p '请选择 [1]： ' choice < /dev/tty || fail "未完成 DataMind API Key 配置"
    choice="${choice:-1}"

    case "$choice" in
      1)
        if register_free_cloud_key; then
          return 0
        fi
        ;;
      2)
        read_existing_cloud_key || fail "未完成 DataMind API Key 配置"
        return 0
        ;;
      3|q|Q)
        fail "用户取消安装"
        ;;
      *)
        printf '请输入 1、2 或 3。\n' >&2
        ;;
    esac
  done
}

validate_cloud_api_key() {
  local value="$1"
  validate_secret "DataMind API Key" "$value"
  [[ "$value" == dm_free_* || "$value" == dm_member_* ]] ||
    fail "DataMind API Key 格式不正确；请使用 Cloud 注册后获得的 dm_free_... 或会员 Key"
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
check_cloud_network
select_release_base

ENV_FILE="$INSTALL_DIR/.env"
if [[ -z "$API_KEY" ]]; then
  API_KEY="$(read_env_value "$ENV_FILE" "DATAMIND_CLOUD_API_KEY")"
fi
obtain_cloud_api_key
validate_cloud_api_key "$API_KEY"

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
