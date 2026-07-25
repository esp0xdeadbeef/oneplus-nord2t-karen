#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
privacy_script="$script_directory/scripts/nord2t-privacy"
device_makefile="$script_directory/lineage/device/oneplus/karen/device.mk"
boot_audit="$script_directory/scripts/audit-boot-image"
image_audit="$script_directory/scripts/audit-lineage-images"
keybound_helper="$script_directory/scripts/lineage-keybound-adb"
runtime_audit="$script_directory/scripts/audit-lineage-runtime"

critical_packages=(
  com.android.permissioncontroller
  com.android.systemui
  com.google.android.dialer
  com.google.android.inputmethod.latin
  com.google.android.modulemetadata
  com.google.android.networkstack
  com.google.android.webview
  com.oplus.camera
  com.oplus.ota
)

for package in "${critical_packages[@]}"; do
  if grep -Eq "^[[:space:]]+$package([[:space:]]|$)" "$privacy_script"; then
    echo "Critical package appears in a disable list: $package" >&2
    exit 1
  fi
done

grep -Fq 'model" != CPH2399' "$privacy_script"
grep -Fq 'device" != OP557AL1' "$privacy_script"
grep -Fq 'pm disable-user --user 0' "$privacy_script"
grep -Fq 'pm default-state --user 0' "$privacy_script"
grep -Fq 'boot_state_source=kernel_cmdline' "$privacy_script"
grep -Fq 'read_kernel_androidboot vbmeta.device_state' "$privacy_script"

# shellcheck disable=SC2016
grep -Fq 'PRODUCT_ADB_KEYS := $(strip $(KAREN_DEBUG_ADB_KEYS))' "$device_makefile"
grep -Fq -- '--allow-embedded-adb-key' "$boot_audit"
grep -Fq -- '--allow-embedded-adb-key' "$image_audit"
grep -Fq 'flash_partition vbmeta_a' "$keybound_helper"
grep -Fq 'flash_partition boot_a' "$keybound_helper"
grep -Fq 'embedded ADB key does not match this normal-user host key' "$keybound_helper"
grep -Fq 'expected exactly one device already in bootloader-fastboot' "$keybound_helper"
grep -Fq 'slot A is not active' "$keybound_helper"
if grep -Eq \
  'flash_partition (system|system_ext|product|vendor|odm|dtbo|vbmeta_system|vbmeta_vendor)' \
  "$keybound_helper"; then
  echo "Key-bound ADB helper can write outside boot_a/vbmeta_a." >&2
  exit 1
fi
if grep -Eq \
  'fastboot .*(erase|format|delete-logical-partition|create-logical-partition|resize-logical-partition)' \
  "$keybound_helper"; then
  echo "Key-bound ADB helper contains a destructive non-boot operation." >&2
  exit 1
fi
grep -Fq 'voice_calls_sms_and_emergency_calls' "$runtime_audit"
grep -Fq 'charging_and_thermal_behavior' "$runtime_audit"
grep -Fq 'echo "manual_check=' "$runtime_audit"
grep -Fq 'ro.crypto.state' "$runtime_audit"
grep -Fq 'ro.boot.verifiedbootstate' "$runtime_audit"
grep -Fq 'getenforce' "$runtime_audit"
if grep -Eqi \
  '(android_id|serialno|imei|subscriber|iphonesubinfo|dumpsys (wifi|telephony)|ip addr|/sys/class/net|su -c|/dev/block/by-name/(nvram|nvdata|persist|proinfo|protect1|protect2))' \
  "$runtime_audit"; then
  echo "Runtime audit can read identifying or device-unique data." >&2
  exit 1
fi
if find "$script_directory/lineage" \
  -type f \
  \( -name adb_keys -o -name 'adbkey*' -o -name '*.pub' \) \
  -print -quit |
  grep -q .; then
  echo "A host ADB key is present in the tracked Lineage source tree." >&2
  exit 1
fi

echo "Package safety checks passed."
