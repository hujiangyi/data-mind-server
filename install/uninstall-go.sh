#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="${DATAMIND_GO_INSTALL_DIR:-/opt/datamind-go}"
SERVICE_NAME="${DATAMIND_GO_SERVICE_NAME:-datamind-go}"

[[ "$EUID" -eq 0 ]] || {
  printf '错误：卸载 Linux Go 服务需要 root 权限\n' >&2
  exit 1
}

systemctl disable --now "$SERVICE_NAME.service" 2>/dev/null || true
rm -f "/etc/systemd/system/$SERVICE_NAME.service"
systemctl daemon-reload

if [[ "${DATAMIND_GO_PURGE_DATA:-0}" == "1" ]]; then
  rm -rf "$INSTALL_DIR"
  userdel datamind 2>/dev/null || true
  printf 'DataMind Go 服务和数据已删除：%s\n' "$INSTALL_DIR"
else
  rm -rf "$INSTALL_DIR/bin" "$INSTALL_DIR/migrations" "$INSTALL_DIR/configs"
  printf 'DataMind Go 服务已卸载，数据和配置仍保留：%s\n' "$INSTALL_DIR"
fi
