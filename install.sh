#!/usr/bin/env bash
set -Eeuo pipefail

CUSTOM_VERSION="v1.13-user-monitor.1"
CUSTOM_SHA256="c3c038b5784f7ec4664ba56f6400b9860dd0904fc683aef99c6deb13e3e77b30"
DEFAULT_BINARY_URL="https://github.com/PivKeyU/XboardNode/releases/download/v1.13-user-monitor.1/xboard-node-user-monitor-linux-amd64"
UNCONFIGURED_BINARY_URL="__XBOARD_"USER_MONITOR_BINARY_URL__
OFFICIAL_INSTALLER_URL="https://raw.githubusercontent.com/cedar2025/xboard-node/0a29338e1f102a462363ce3527417029f89bab28/install.sh"
OFFICIAL_INSTALLER_SHA256="d0323e37dfbb24fd34efa62cdb96b0f3c5594791d0a50f6f4f66af6f570dad8e"

BINARY_URL="${XBOARD_USER_MONITOR_BINARY_URL:-$DEFAULT_BINARY_URL}"
BINARY_SHA256="${XBOARD_USER_MONITOR_SHA256:-$CUSTOM_SHA256}"
ACTION=""
TMP_DIR=""
FORWARD_ARGS=()

log() {
  printf '[user-monitor] %s\n' "$*"
}

fail() {
  printf '[user-monitor] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf -- "$TMP_DIR"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'HELP'
XBoard User Monitor 节点一键安装/升级器

新增参数：
  --binary-url URL       监控版 xboard-node 二进制下载地址
  --binary-sha256 HASH   二进制 SHA256；默认使用发布包内置值

其余参数与官方 xboard-node install.sh 相同。

新装示例：
  curl -fsSL https://raw.githubusercontent.com/PivKeyU/XboardNode/main/install.sh | sudo bash -s -- \
    --mode machine --panel https://panel.example.com --token TOKEN --machine-id 13

升级示例（自动保留 /etc/xboard-node/config.yml）：
  curl -fsSL https://raw.githubusercontent.com/PivKeyU/XboardNode/main/install.sh | sudo bash

如需使用镜像，可通过环境变量覆盖二进制下载地址：
  XBOARD_USER_MONITOR_BINARY_URL=https://你的下载域名/xboard-node-user-monitor-linux-amd64
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --binary-url)
      [[ $# -ge 2 ]] || fail "--binary-url 缺少值"
      BINARY_URL="$2"
      shift 2
      ;;
    --binary-sha256)
      [[ $# -ge 2 ]] || fail "--binary-sha256 缺少值"
      BINARY_SHA256="$2"
      shift 2
      ;;
    --binary)
      fail "请使用 --binary-url；不允许覆盖经过校验的监控版节点程序"
      ;;
    install|upgrade|status|uninstall)
      ACTION="$1"
      shift
      ;;
    --help|-h|help)
      usage
      exit 0
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] || fail "请使用 root 运行，或通过 sudo bash 执行"
command -v curl >/dev/null 2>&1 || fail "系统缺少 curl"
command -v sha256sum >/dev/null 2>&1 || fail "系统缺少 sha256sum"

case "$(uname -m)" in
  x86_64|amd64) ;;
  *) fail "当前发布包仅支持 Linux x86_64/amd64" ;;
esac

if [[ -z "$ACTION" ]]; then
  if [[ -x /usr/local/bin/xboard-node \
    && -f /etc/xboard-node/config.yml \
    && -f /etc/systemd/system/xboard-node.service ]]; then
    ACTION="upgrade"
  else
    ACTION="install"
  fi
fi

TMP_DIR="$(mktemp -d)"
OFFICIAL_INSTALLER="$TMP_DIR/official-install.sh"
CUSTOM_BINARY="$TMP_DIR/xboard-node-user-monitor-linux-amd64"

log "下载固定版本的官方安装器"
curl --retry 3 --retry-delay 2 -fsSL "$OFFICIAL_INSTALLER_URL" -o "$OFFICIAL_INSTALLER"
printf '%s  %s\n' "$OFFICIAL_INSTALLER_SHA256" "$OFFICIAL_INSTALLER" | sha256sum -c -
chmod 0700 "$OFFICIAL_INSTALLER"

if [[ "$ACTION" == "status" || "$ACTION" == "uninstall" ]]; then
  bash "$OFFICIAL_INSTALLER" "$ACTION" "${FORWARD_ARGS[@]}"
  exit
fi

if [[ -z "$BINARY_URL" || "$BINARY_URL" == "$UNCONFIGURED_BINARY_URL" ]]; then
  fail "尚未配置二进制下载地址；请传入 --binary-url，或先生成已写入默认地址的发布脚本"
fi
case "$BINARY_URL" in
  https://*) ;;
  *) fail "为避免中间人替换节点程序，--binary-url 必须使用 HTTPS" ;;
esac
[[ "$BINARY_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || fail "二进制 SHA256 格式不正确"

log "下载监控版节点：$CUSTOM_VERSION"
curl --retry 3 --retry-delay 2 -fsSL "$BINARY_URL" -o "$CUSTOM_BINARY"
printf '%s  %s\n' "${BINARY_SHA256,,}" "$CUSTOM_BINARY" | sha256sum -c -
chmod 0755 "$CUSTOM_BINARY"

VERSION_OUTPUT="$("$CUSTOM_BINARY" -v)"
[[ "$VERSION_OUTPUT" == *"$CUSTOM_VERSION"* ]] \
  || fail "版本检查失败：期望 $CUSTOM_VERSION，实际为 $VERSION_OUTPUT"

if [[ "$ACTION" == "upgrade" ]]; then
  log "检测到现有节点，将保留配置并执行升级"
else
  log "未检测到完整安装，将按传入的 panel/token/machine-id 创建配置"
fi

bash "$OFFICIAL_INSTALLER" "$ACTION" --binary "$CUSTOM_BINARY" "${FORWARD_ARGS[@]}"

log "完成：$(/usr/local/bin/xboard-node -v)"
if command -v xbctl >/dev/null 2>&1; then
  xbctl status
fi
