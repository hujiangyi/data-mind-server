#!/usr/bin/env bash
set -Eeuo pipefail

export LC_ALL=C
export LC_CTYPE=C
export LANG=C

VERSION="${DATAMIND_GO_VERSION:-latest}"
INSTALL_MODE="${DATAMIND_GO_INSTALL_MODE:-auto}"
GITHUB_RELEASE_BASE="${DATAMIND_GITHUB_RELEASE_BASE:-https://github.com/hujiangyi/data-mind-server/releases/download}"
GITEE_RELEASE_BASE="${DATAMIND_GITEE_RELEASE_BASE:-https://gitee.com/hujiangyi/data-mind-server/releases/download}"
RELEASE_BASE="${DATAMIND_RELEASE_BASE:-}"
RELEASE_SOURCE="${DATAMIND_RELEASE_SOURCE:-auto}"
INSTALL_DIR="${DATAMIND_GO_INSTALL_DIR:-/opt/datamind-go}"
SERVICE_NAME="${DATAMIND_GO_SERVICE_NAME:-datamind-go}"
CLOUD_API_BASE="${DATAMIND_CLOUD_API_BASE:-https://dm.iter-self.top/v1}"
API_KEY="${DATAMIND_CLOUD_API_KEY:-}"
BIND_ADDRESS="${DATAMIND_BIND_ADDRESS:-0.0.0.0}"
PORT="${DATAMIND_PORT:-3001}"
MCP_MASTER_KEY="${DAAS_MCP_MASTER_KEY:-}"
MCP_SETUP_BASE_URL="${DAAS_MCP_SETUP_BASE_URL:-}"
MCP_PUBLIC_API_BASE="${DAAS_MCP_PUBLIC_API_BASE:-}"
SERVER_IP="${DATAMIND_SERVER_IP:-}"
API_KEY_OBTAINED=0
INSTALL_VERBOSE="${DATAMIND_INSTALL_VERBOSE:-0}"
EXISTING_INSTALL=0
REINSTALL_CONFIRMED=0
CURRENT_VERSION=""
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
  if ! command -v "$1" >/dev/null 2>&1; then
    if [[ "$INSTALL_VERBOSE" == "1" ]]; then
      printf '详细信息：缺少命令 %s\n' "$1" >&2
    fi
    fail "安装环境不满足要求，请补齐系统依赖后重试"
  fi
}

read_env_value() {
  local file="$1"
  local name="$2"
  [[ -f "$file" ]] || return 0
  awk -v name="$name" 'index($0, name "=") == 1 {sub(/^[^=]*=/, ""); value=$0} END {print value}' "$file"
}

detect_existing_install() {
  if [[ -f "$INSTALL_DIR/VERSION" || -f "$INSTALL_DIR/data/maicong.db" ||
        -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
    EXISTING_INSTALL=1
    if [[ -f "$INSTALL_DIR/VERSION" ]]; then
      CURRENT_VERSION="$(tr -d '[:space:]' < "$INSTALL_DIR/VERSION")"
    fi
  fi
}

select_install_mode() {
  [[ "$INSTALL_MODE" == "auto" || "$INSTALL_MODE" == "new" ||
    "$INSTALL_MODE" == "update" || "$INSTALL_MODE" == "reinstall" ]] ||
    fail "DATAMIND_GO_INSTALL_MODE 只能是 auto、new、update 或 reinstall"

  detect_existing_install
  if [[ "$EXISTING_INSTALL" -eq 0 ]]; then
    [[ "$INSTALL_MODE" != "update" ]] || fail "没有检测到已有 DataMind Go 安装，不能执行更新"
    [[ "$INSTALL_MODE" != "reinstall" ]] || fail "没有检测到已有 DataMind Go 安装，不能执行重装"
    INSTALL_MODE="new"
    return
  fi

  [[ "$INSTALL_MODE" != "new" ]] ||
    fail "检测到已有 DataMind Go 安装（${CURRENT_VERSION:-版本未知}）。如需保留数据，请使用 DATAMIND_GO_INSTALL_MODE=update；如需清空后重装，请使用 DATAMIND_GO_INSTALL_MODE=reinstall。"

  if [[ "$INSTALL_MODE" == "auto" ]]; then
    if [[ -r /dev/tty ]]; then
      printf '\n检测到已有 DataMind Go 安装：%s\n' "${CURRENT_VERSION:-版本未知}"
      printf '请选择操作：\n'
      printf '  1) 更新到 %s（保留数据、配置和 Cloud Key，推荐）\n' "$VERSION"
      printf '  2) 重新安装（清除已关联数据源、子账号和数据权限）\n'
      printf '  3) 退出\n'
      local choice
      read -r -p '请选择 [1]： ' choice < /dev/tty || fail "未完成安装模式选择"
      case "${choice:-1}" in
        1) INSTALL_MODE="update" ;;
        2) INSTALL_MODE="reinstall" ;;
        3|q|Q) fail "用户取消安装" ;;
        *) fail "请输入 1、2 或 3" ;;
      esac
    else
      INSTALL_MODE="update"
    fi
  fi

  if [[ "$INSTALL_MODE" == "reinstall" ]]; then
    printf '\n警告：重新安装会删除当前 DataMind Go 的本地数据和配置。\n'
    printf '以下内容将丢失：已经关联的数据源、分配的子账号、数据权限和本地审计数据。\n'
    printf '重新安装后需要重新配置；此操作不能通过安装器自动恢复。\n'
    if [[ -r /dev/tty ]]; then
      local confirmation
      read -r -p '确认继续请输入 REINSTALL，其他输入退出： ' confirmation < /dev/tty ||
        fail "未完成重装确认"
      [[ "$confirmation" == "REINSTALL" ]] || fail "用户取消重装"
    else
      [[ "${DATAMIND_GO_REINSTALL_CONFIRM:-}" == "REINSTALL" ]] ||
        fail "非交互重装必须设置 DATAMIND_GO_REINSTALL_CONFIRM=REINSTALL"
    fi
    REINSTALL_CONFIRMED=1
  fi
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
    if curl --fail --silent --location --ipv4 --http1.1 \
        "${CURL_EXTRA_ARGS[@]}" \
        --connect-timeout 4 --max-time 8 \
        -o /dev/null "$root/checksums.txt" 2>/dev/null; then
      return 0
    fi
  else
    if wget --quiet --timeout=5 --tries=1 -O /dev/null "$root/checksums.txt"; then
      return 0
    fi
  fi
  return 1
}

check_cloud_network() {
  local endpoint="${CLOUD_API_BASE%/}/"
  local status

  printf '[3/5] 检查 Cloud AI 网络连接 ... '
  if command -v curl >/dev/null 2>&1; then
    if status="$(curl --silent --show-error --location --ipv4 --http1.1 \
        "${CURL_EXTRA_ARGS[@]}" \
        --connect-timeout 3 --max-time 8 \
        -o /dev/null -w '%{http_code}' "$endpoint" 2>/dev/null)" &&
        [[ "$status" != "000" ]]; then
      printf '通过\n'
      return 0
    fi
    if [[ -z "${DATAMIND_CURL_PROXY:-}" && "${DATAMIND_CURL_NO_PROXY:-0}" != "1" ]]; then
      if status="$(curl --silent --show-error --location --ipv4 --http1.1 \
          --noproxy '*' \
          --connect-timeout 3 --max-time 8 \
          -o /dev/null -w '%{http_code}' "$endpoint" 2>/dev/null)" &&
          [[ "$status" != "000" ]]; then
        CURL_EXTRA_ARGS+=(--noproxy '*')
        printf '通过\n'
        return 0
      fi
    fi
    printf '未通过\n' >&2
    printf '提示：可以设置 DATAMIND_CURL_NO_PROXY=1 使用直连，或设置 DATAMIND_CURL_PROXY 使用指定代理。\n' >&2
    fail "安装环境不满足要求：外部网络不可用"
  fi

  if wget --quiet --timeout=5 --tries=1 -O /dev/null "$endpoint"; then
    printf '通过\n'
    return 0
  fi
  printf '未通过\n' >&2
  fail "安装环境不满足要求：外部网络不可用"
}

select_release_base() {
  if [[ -n "$RELEASE_BASE" ]]; then
    if ! probe_release "$RELEASE_BASE"; then
      fail "安装环境不满足要求：指定的下载源不可用"
    fi
    printf '[4/5] 检查 Release 下载源 ... 通过（已指定）\n'
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
      printf '[4/5] 检查 Release 下载源 ... '
      for source in gitee github; do
        if [[ "$source" == "gitee" ]]; then
          candidate="$GITEE_RELEASE_BASE"
        else
          candidate="$GITHUB_RELEASE_BASE"
        fi
        if probe_release "$candidate"; then
          RELEASE_BASE="$candidate"
          printf '通过（%s）\n' "$source"
          return 0
        fi
      done
      printf '未通过\n' >&2
      fail "安装环境不满足要求：没有可用的下载源"
      ;;
    *)
      fail "DATAMIND_RELEASE_SOURCE 只能是 auto、github 或 gitee"
      ;;
  esac
  if ! probe_release "$RELEASE_BASE"; then
    fail "安装环境不满足要求：指定的下载源不可用"
  fi
  printf '[4/5] 检查 Release 下载源 ... 通过\n'
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

issue_existing_cloud_key() {
  local email="$1"
  local password="$2"
  local payload
  local response_file
  local status
  local existing_key
  local key_kind
  local key_url="${CLOUD_API_BASE%/}/cloud/auth/installer-key"

  payload="$(printf '{"email":"%s","password":"%s"}' "$(json_escape "$email")" "$(json_escape "$password")")"
  response_file="$(mktemp "${TMPDIR:-/tmp}/datamind-cloud-key.XXXXXX")"
  if ! status="$(printf '%s' "$payload" | curl --silent --show-error --location --ipv4 --http1.1 \
      "${CURL_EXTRA_ARGS[@]}" \
      --retry 2 --retry-delay 1 --connect-timeout 10 --max-time 30 \
      -H 'content-type: application/json' \
      --data-binary @- -o "$response_file" -w '%{http_code}' "$key_url")"; then
    rm -f "$response_file"
    printf '无法完成账号验证，请检查网络或稍后重试。\n' >&2
    return 1
  fi

  existing_key="$(json_data_value "$response_file" key)"
  key_kind="$(json_data_value "$response_file" keyKind)"
  rm -f "$response_file"

  case "$status" in
    200|201)
      if [[ "$existing_key" != dm_free_* && "$existing_key" != dm_member_* ]]; then
        printf '账号验证成功，但没有取得有效的 DataMind API Key，请稍后重试。\n' >&2
        return 1
      fi
      API_KEY="$existing_key"
      API_KEY_OBTAINED=1
      printf '邮箱已注册，密码验证通过，已取得 DataMind API Key（%s）。\n' "${key_kind:-free}"
      return 0
      ;;
    401|403)
      printf '邮箱或 Cloud 登录密码不匹配，请重新输入。\n' >&2
      return 1
      ;;
    *)
      printf '账号验证未完成，请检查网络或稍后重试。\n' >&2
      return 1
      ;;
  esac
}

register_free_cloud_key() {
  local email
  local password
  local payload
  local response_file
  local status
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

  read -r -p '设置 Cloud 登录密码（至少 8 位，可见输入）： ' password < /dev/tty || return 1
  printf '\n'
  if [[ "${#password}" -lt 8 ]]; then
    printf '密码至少需要 8 位，请重新注册。\n' >&2
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
  rm -f "$response_file"

  case "$status" in
    200|201)
      if [[ "$registered_key" != dm_free_* ]]; then
        printf 'Cloud 注册响应中没有有效的免费 API Key，请稍后重试。\n' >&2
        return 1
      fi
      API_KEY="$registered_key"
      API_KEY_OBTAINED=1
      printf 'Cloud 账号注册成功，已获取免费 DataMind API Key（%s）。\n' "${key_kind:-free}"
      return 0
      ;;
    400)
      printf 'Cloud 注册资料无效，请检查邮箱和密码后重试。\n' >&2
      return 1
      ;;
    409)
      issue_existing_cloud_key "$email" "$password"
      return $?
      ;;
    *)
      printf 'Cloud 注册未完成，请检查网络或稍后重试，也可以输入已有 DataMind API Key。\n' >&2
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

port_is_listening() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltnH 2>/dev/null |
      awk -v port="$PORT" '$4 ~ (":" port "$") {found=1} END {exit !found}'
    return $?
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  return 2
}

check_port_available() {
  local port_status=0
  printf '[5/5] 检查服务端口 ... '
  port_is_listening || port_status=$?
  if [[ "$port_status" -eq 0 ]]; then
    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
      printf '通过（已有 DataMind 服务）\n'
      return 0
    fi
    printf '未通过\n' >&2
    fail "服务端口已被占用，请停止占用端口的程序后重试"
  fi
  if [[ "$port_status" -eq 2 ]]; then
    printf '未通过\n' >&2
    fail "无法检查服务端口，请安装 ss 或 lsof 后重试"
  fi
  printf '通过（%s:%s）\n' "$BIND_ADDRESS" "$PORT"
}

check_install_environment() {
  printf '检查安装环境\n'
  printf '隐私说明：DataMind 不会保留或记录用户私有业务数据，请放心使用。\n'
  printf '提示：数据源配置、元数据、账号权限和审计信息仅保存在您自己的 DataMind 部署环境中。\n'
  printf '[1/5] 检查系统权限和架构 ... 通过（Linux %s）\n' "$ARCH"
  printf '[2/5] 检查必要依赖 ... '
  require_command tar
  require_command awk
  require_command systemctl
  require_command openssl
  require_command curl
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    fail "安装环境不满足要求，请补齐系统依赖后重试"
  fi
  if ! command -v ss >/dev/null 2>&1 && ! command -v lsof >/dev/null 2>&1; then
    fail "安装环境不满足要求，请安装 ss 或 lsof 后重试"
  fi
  printf '通过\n'
  check_cloud_network
  select_release_base
  check_port_available
}

check_service_ready() {
  systemctl is-active --quiet "$SERVICE_NAME.service" || return 1
  port_is_listening || return 1
  curl --fail --silent --show-error \
    --connect-timeout 2 --max-time 5 \
    -o /dev/null "http://127.0.0.1:$PORT/health" 2>/dev/null
}

wait_for_service_ready() {
  local attempt
  for attempt in $(seq 1 45); do
    if check_service_ready; then
      return 0
    fi
    sleep 2
  done
  return 1
}

check_runtime_binary() {
  local pid
  local executable
  pid="$(systemctl show -p MainPID --value "$SERVICE_NAME.service")"
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || fail "无法取得 DataMind Go 运行进程 PID"
  executable="$(readlink "/proc/$pid/exe" 2>/dev/null || true)"
  [[ "$executable" == "$INSTALL_DIR/bin/daas-go" ]] ||
    fail "服务运行的二进制路径异常：$executable"
  [[ "$executable" != *" (deleted)"* ]] ||
    fail "服务仍运行在已删除的旧版二进制上，请执行 systemctl restart $SERVICE_NAME.service 后重试"
}

check_cloud_ai_capability() {
  local payload
  local response_file
  local status
  local message
  local endpoint="${CLOUD_API_BASE%/}/cloud/ai/welcome"

  printf '检查 Cloud AI 能力 ... '
  payload='{"stream":false}'
  response_file="$(mktemp "${TMPDIR:-/tmp}/datamind-cloud-welcome.XXXXXX")"
  if ! status="$(printf '%s' "$payload" | curl --silent --show-error --location --ipv4 --http1.1 \
      "${CURL_EXTRA_ARGS[@]}" \
      --retry 1 --connect-timeout 8 --max-time 45 \
      -H "Authorization: Bearer $API_KEY" \
      -H 'content-type: application/json' \
      --data-binary @- -o "$response_file" -w '%{http_code}' "$endpoint" 2>/dev/null)"; then
    rm -f "$response_file"
    printf '未通过\n' >&2
    return 1
  fi
  if [[ "$status" != 2* ]]; then
    rm -f "$response_file"
    printf '未通过\n' >&2
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    message="$(jq -r '.data.message // empty' "$response_file" 2>/dev/null || true)"
  else
    message="$(sed -nE 's/.*"message":[[:space:]]*"([^"]*)".*/\1/p' "$response_file" | head -1)"
  fi
  rm -f "$response_file"
  if [[ -z "$message" ]]; then
    printf '未通过\n' >&2
    return 1
  fi
  message="$(printf '%s' "$message" | tr '\r\n' ' ' | tr -d '\000-\037\177')"
  printf '通过，AI 欢迎语：%s\n' "$message"
  return 0
}

check_cloud_go_compatibility() {
  local response_file
  local status
  local compatible
  local supported
  local recommended
  local endpoint="${CLOUD_API_BASE%/}/cloud/server/compatibility"

  printf '检查 Cloud Go 版本兼容性 ... '
  response_file="$(mktemp "${TMPDIR:-/tmp}/datamind-cloud-compatibility.XXXXXX")"
  if ! status="$(curl --silent --show-error --location --ipv4 --http1.1 \
      "${CURL_EXTRA_ARGS[@]}" \
      --connect-timeout 8 --max-time 15 \
      --get --data-urlencode "goVersion=$VERSION" \
      --data-urlencode "operation=$INSTALL_MODE" \
      -o "$response_file" -w '%{http_code}' "$endpoint" 2>/dev/null)"; then
    rm -f "$response_file"
    printf '未通过\n' >&2
    fail "无法向 DataMind Cloud 查询 Go 版本兼容性，为避免安装不受支持的版本，安装已中止"
  fi
  if [[ "$status" != "2"* ]]; then
    rm -f "$response_file"
    printf '未通过\n' >&2
    fail "DataMind Cloud 暂时无法提供 Go 版本兼容列表（HTTP $status），安装已中止"
  fi
  if command -v jq >/dev/null 2>&1; then
    compatible="$(jq -r '.data.compatible // false' "$response_file" 2>/dev/null || true)"
    supported="$(jq -r '(.data.supportedGoVersions // []) | join(", ")' "$response_file" 2>/dev/null || true)"
    recommended="$(jq -r '.data.recommendedGoVersion // empty' "$response_file" 2>/dev/null || true)"
  else
    compatible="$(sed -nE 's/.*"compatible":[[:space:]]*(true|false).*/\1/p' "$response_file" | head -1)"
    supported="$(sed -nE 's/.*"supportedGoVersions":[[:space:]]*\[([^]]*)\].*/\1/p' "$response_file" | tr -d '"' | tr ',' ' ')"
    recommended="$(sed -nE 's/.*"recommendedGoVersion":[[:space:]]*"([^"]+)".*/\1/p' "$response_file" | head -1)"
  fi
  rm -f "$response_file"
  [[ -n "$supported" && -n "$recommended" ]] || {
    printf '未通过\n' >&2
    fail "DataMind Cloud 兼容响应不完整，缺少支持版本或推荐版本，安装已中止"
  }
  if [[ "$compatible" != "true" ]]; then
    printf '不支持\n' >&2
    printf '提示：Cloud 当前支持的 Go 版本：%s。\n' "$supported"
    printf '建议版本：%s。请改用 DATAMIND_GO_VERSION=%s 重试。\n' "$recommended" "$recommended"
    fail "目标 Go 版本 $VERSION 与当前 DataMind Cloud 不兼容"
  fi
  printf '通过（%s -> %s）\n' "${CURRENT_VERSION:-新装}" "$VERSION"
}

show_obtained_api_key() {
  if [[ "$API_KEY_OBTAINED" -eq 1 ]]; then
    printf '\nDataMind Cloud API Key（请立即保存）：\n%s\n' "$API_KEY"
    printf '服务端保存位置：%s\n' "$ENV_FILE"
    printf '提醒：终端记录可能包含此 Key，请勿分享或提交到公开仓库。\n'
  fi
}

print_admin_guidance() {
  printf '\nWeb 管理入口：http://127.0.0.1:%s\n' "$PORT"
  if [[ "$BIND_ADDRESS" != "127.0.0.1" && "$BIND_ADDRESS" != "::1" && "$BIND_ADDRESS" != "localhost" ]]; then
    if [[ -z "$SERVER_IP" ]]; then
      SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    fi
    if [[ -z "$SERVER_IP" && -r /proc/net/route ]]; then
      SERVER_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
    fi
    if [[ -n "$SERVER_IP" ]]; then
      printf '服务器访问：http://%s:%s\n' "$SERVER_IP" "$PORT"
    else
      printf '服务器访问：http://{server_ip}:%s\n' "$PORT"
      printf '提示：未能自动识别服务器 IP，请将 {server_ip} 替换为本机可访问的服务器地址。\n'
    fi
  fi
  printf '全新安装管理员账号：admin\n'
  printf '全新安装管理员初始密码：123456\n'
  printf '首次登录必须修改为 8～16 位新密码；管理员创建或重置的账号也使用此初始密码。\n'
  printf '\n管理员操作指南：\n'
  printf 'GitHub：https://github.com/hujiangyi/data-mind-server/blob/main/docs/zh-CN/admin-guide.md\n'
  printf 'Gitee： https://gitee.com/hujiangyi/data-mind-server/blob/main/docs/zh-CN/admin-guide.md\n'
}

configure_runtime_config() {
  local config_file="$1"
  local temp_file
  [[ -f "$config_file" ]] || fail "Release 缺少运行配置"
  grep -q '^server:[[:space:]]*$' "$config_file" ||
    fail "运行配置缺少 server 设置"

  temp_file="${config_file}.tmp.$$"
  awk -v desired_host="$BIND_ADDRESS" -v desired_port="$PORT" '
    function emit_missing() {
      if (in_server && !host_done) print "  host: \"" desired_host "\""
      if (in_server && !port_done) print "  port: " desired_port
    }
    /^server:[[:space:]]*$/ {
      in_server = 1
      host_done = 0
      port_done = 0
      print
      next
    }
    {
      if (in_server && $0 !~ /^[[:space:]]/ && $0 !~ /^[[:space:]]*$/) {
        emit_missing()
        in_server = 0
      }
      if (in_server && $0 ~ /^[[:space:]]+host:[[:space:]]*/) {
        print "  host: \"" desired_host "\""
        host_done = 1
        next
      }
      if (in_server && $0 ~ /^[[:space:]]+port:[[:space:]]*/) {
        print "  port: " desired_port
        port_done = 1
        next
      }
      print
    }
    END {
      emit_missing()
    }
  ' "$config_file" > "$temp_file"
  mv "$temp_file" "$config_file"
}

[[ "$EUID" -eq 0 ]] || fail "Linux Go 服务需要 root 权限，请使用 sudo 或 root 执行"
[[ "$CLOUD_API_BASE" =~ ^https?://[^[:space:]]+$ ]] || fail "DATAMIND_CLOUD_API_BASE 必须是 HTTP 或 HTTPS 地址"
[[ "$BIND_ADDRESS" =~ ^[A-Za-z0-9_.:-]+$ ]] || fail "DATAMIND_BIND_ADDRESS 格式不正确"
[[ "$PORT" =~ ^[0-9]+$ && "$PORT" -ge 1 && "$PORT" -le 65535 ]] ||
  fail "DATAMIND_PORT 必须是 1 到 65535 之间的端口"

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) fail "不支持的 Linux 架构：$(uname -m)" ;;
esac

ASSET="datamind-go-linux-$ARCH.tar.gz"
select_install_mode
check_install_environment

ENV_FILE="$INSTALL_DIR/.env"
if [[ "$INSTALL_MODE" == "reinstall" ]]; then
  API_KEY=""
fi
if [[ "$INSTALL_MODE" != "reinstall" && -z "$API_KEY" ]]; then
  API_KEY="$(read_env_value "$ENV_FILE" "DATAMIND_CLOUD_API_KEY")"
fi
obtain_cloud_api_key
validate_cloud_api_key "$API_KEY"
check_cloud_go_compatibility

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
[[ -x "$EXTRACT_ROOT/bin/datamind-upgrade" ]] || fail "Release 缺少 bin/datamind-upgrade，拒绝执行未带升级工具的 Release"
[[ -f "$EXTRACT_ROOT/configs/config.yaml" ]] || fail "Release 缺少 configs/config.yaml"
[[ -d "$EXTRACT_ROOT/migrations" ]] || fail "Release 缺少 migrations 目录"
[[ -f "$EXTRACT_ROOT/migration-manifest.json" ]] || fail "Release 缺少 migration-manifest.json，拒绝执行未校验迁移链的 Release"
[[ -f "$EXTRACT_ROOT/frontend-build.json" ]] || fail "Release 缺少 frontend-build.json，拒绝执行未绑定 Vue 构建信息的 Release"

if [[ "$INSTALL_MODE" == "reinstall" ]]; then
  [[ "$REINSTALL_CONFIRMED" -eq 1 ]] || fail "重装确认状态无效"
  printf '停止并清理旧版 DataMind Go，准备全新安装 %s ...\n' "$VERSION"
  systemctl disable --now "$SERVICE_NAME.service" 2>/dev/null || true
  rm -f "/etc/systemd/system/$SERVICE_NAME.service"
  systemctl daemon-reload
  rm -rf "$INSTALL_DIR"
elif [[ "$INSTALL_MODE" == "update" ]]; then
  printf '停止旧版 DataMind Go 服务，准备切换到 %s ...\n' "$VERSION"
  systemctl stop "$SERVICE_NAME.service" ||
    fail "无法停止旧版 DataMind Go 服务，已取消更新"
fi

mkdir -p "$INSTALL_DIR"
if [[ ! -f "$INSTALL_DIR/configs/config.yaml" ]]; then
  mkdir -p "$INSTALL_DIR/configs"
  cp "$EXTRACT_ROOT/configs/config.yaml" "$INSTALL_DIR/configs/config.yaml"
fi
configure_runtime_config "$INSTALL_DIR/configs/config.yaml"
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp"
mkdir -p "$INSTALL_DIR/backups"
printf '执行 DataMind %s 数据库和配置升级 ...\n' "$VERSION"
"$EXTRACT_ROOT/bin/datamind-upgrade" \
  -db "$INSTALL_DIR/data/maicong.db" \
  -migrations "$EXTRACT_ROOT/migrations" \
  -manifest "$EXTRACT_ROOT/migration-manifest.json" \
  -config "$INSTALL_DIR/configs/config.yaml" \
  -backup-dir "$INSTALL_DIR/backups" \
  -version "$VERSION" ||
  fail "DataMind 数据库或配置升级失败，未切换新版本；请检查 backups 和迁移错误"
rm -rf "$INSTALL_DIR/bin" "$INSTALL_DIR/migrations"
cp -R "$EXTRACT_ROOT/bin" "$INSTALL_DIR/bin"
cp -R "$EXTRACT_ROOT/migrations" "$INSTALL_DIR/migrations"
cp "$EXTRACT_ROOT/migration-manifest.json" "$INSTALL_DIR/migration-manifest.json"
cp "$EXTRACT_ROOT/frontend-build.json" "$INSTALL_DIR/frontend-build.json"
printf '%s\n' "$VERSION" > "$INSTALL_DIR/VERSION"
chmod 0755 "$INSTALL_DIR/bin/daas-go" "$INSTALL_DIR/bin/datamind-upgrade"

if ! id -u datamind >/dev/null 2>&1; then
  useradd --system --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin datamind
fi

umask 077
ENV_TMP="$TMP_ROOT/.env"
{
  printf 'DATAMIND_BIND_ADDRESS=%s\n' "$BIND_ADDRESS"
  printf 'DATAMIND_PORT=%s\n' "$PORT"
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
show_obtained_api_key

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
if [[ "$INSTALL_MODE" == "update" ]]; then
  systemctl restart "$SERVICE_NAME.service" ||
    fail "DataMind Go 更新后重启失败，请检查系统服务日志"
  systemctl enable "$SERVICE_NAME.service" >/dev/null
else
  systemctl enable --now "$SERVICE_NAME.service" ||
    fail "DataMind 服务启动失败，请检查系统服务日志"
fi

printf '启动并验证 DataMind 服务 ...\n'
if ! wait_for_service_ready; then
  printf '未通过：服务没有在规定时间内完整启动。\n' >&2
  printf '请执行：systemctl status %s.service\n' "$SERVICE_NAME" >&2
  printf '请执行：journalctl -u %s.service -n 100 --no-pager\n' "$SERVICE_NAME" >&2
  printf '卸载命令：{ curl -fsSL https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/uninstall-go.sh || curl -fsSL https://gitee.com/hujiangyi/data-mind-server/raw/main/install/uninstall-go.sh; } | sudo bash\n' >&2
  fail "DataMind 服务启动检查失败"
fi
check_runtime_binary
printf '  服务进程状态：通过\n'
printf '  网络监听状态：通过（%s:%s）\n' "$BIND_ADDRESS" "$PORT"
printf '  网站和 API 健康检查：通过\n'

if ! check_cloud_ai_capability; then
  printf '提示：DataMind 服务已经启动，但 Cloud AI 能力检查未通过。\n' >&2
  printf '请先检查 Cloud 账号额度和网络，再执行：systemctl restart %s.service\n' "$SERVICE_NAME" >&2
  printf '卸载命令：{ curl -fsSL https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/uninstall-go.sh || curl -fsSL https://gitee.com/hujiangyi/data-mind-server/raw/main/install/uninstall-go.sh; } | sudo bash\n' >&2
  print_admin_guidance
  exit 1
fi

printf '\nDataMind Go 安装成功\n'
printf '安装模式：%s\n' "$INSTALL_MODE"
printf '安装目录：%s\n' "$INSTALL_DIR"
printf '服务名称：%s.service\n' "$SERVICE_NAME"
printf '服务监听：%s:%s\n' "$BIND_ADDRESS" "$PORT"
printf '本机访问：http://127.0.0.1:%s\n' "$PORT"
if [[ "$BIND_ADDRESS" != "127.0.0.1" && "$BIND_ADDRESS" != "::1" && "$BIND_ADDRESS" != "localhost" ]]; then
  if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [[ -n "$SERVER_IP" ]]; then
    printf '服务器访问：http://%s:%s\n' "$SERVER_IP" "$PORT"
  else
    printf '服务器访问：http://{server_ip}:%s\n' "$PORT"
  fi
fi
printf '状态检查：systemctl status %s.service\n' "$SERVICE_NAME"
printf '卸载命令：{ curl -fsSL https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/uninstall-go.sh || curl -fsSL https://gitee.com/hujiangyi/data-mind-server/raw/main/install/uninstall-go.sh; } | sudo bash\n'
print_admin_guidance
