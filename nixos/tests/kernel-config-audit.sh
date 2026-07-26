#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d -t karen-kernel-config-test.XXXXXXXX)"
cleanup() {
  chmod -R u+rwX -- "$temporary_directory" 2>/dev/null || true
  rm -rf -- "$temporary_directory"
}
trap cleanup EXIT

cat >"$temporary_directory/config" <<'EOF'
CONFIG_64BIT=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_TMPFS=y
CONFIG_UNIX=y
CONFIG_CGROUPS=y
CONFIG_EPOLL=y
CONFIG_FHANDLE=y
CONFIG_INOTIFY_USER=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_CONFIGFS_FS=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_RNDIS=m
CONFIG_INET=y
CONFIG_NET=y
# CONFIG_KEXEC is not set
CONFIG_ANDROID_BINDER_IPC=y
EOF

config_sha256="$(sha256sum "$temporary_directory/config" | cut -d' ' -f1)"
"$script_directory/tools/kernel-config-audit" \
  "$temporary_directory/config" \
  "$temporary_directory/result"

jq -e \
  --arg configSha256 "$config_sha256" \
  '
    .schemaVersion == 1 and
    .configSha256 == $configSha256 and
    .kexec.classic == "disabled" and
    .kexec.file == "unknown" and
    (
      .entries[] |
      select(.symbol == "CONFIG_USB_CONFIGFS_RNDIS") |
      .value
    ) == "module"
  ' \
  "$temporary_directory/result/report.json" \
  >/dev/null

if "$script_directory/tools/kernel-config-audit" \
  "$temporary_directory/config" \
  "$temporary_directory/result" \
  >/dev/null 2>&1; then
  echo "Kernel config audit unexpectedly overwrote existing output." >&2
  exit 1
fi

echo "NixOS kernel config audit tests passed."
