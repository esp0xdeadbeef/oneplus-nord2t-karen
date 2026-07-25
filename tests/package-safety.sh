#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
device_makefile="$script_directory/lineage/device/oneplus/karen/device.mk"
board_config="$script_directory/lineage/device/oneplus/karen/BoardConfig.mk"
boot_audit="$script_directory/scripts/audit-boot-image"
image_audit="$script_directory/scripts/audit-lineage-images"
keybound_helper="$script_directory/scripts/lineage-keybound-adb"
lineage_root="$script_directory/scripts/lineage-root"
lineage_root_full="$script_directory/scripts/lineage-root-full"
lineage_unroot="$script_directory/scripts/lineage-unroot"
runtime_audit="$script_directory/scripts/audit-lineage-runtime"

# shellcheck disable=SC2016
grep -Fq 'PRODUCT_ADB_KEYS := $(strip $(KAREN_DEBUG_ADB_KEYS))' "$device_makefile"
# shellcheck disable=SC2016
grep -Fq 'ifeq ($(KAREN_DEBUG_PERMISSIVE),true)' "$board_config"
grep -Fq 'BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive' "$board_config"
grep -Fq 'BOARD_KERNEL_CMDLINE += androidboot.slot_suffix=_a' "$board_config"
grep -Fq -- '--allow-embedded-adb-key' "$boot_audit"
grep -Fq -- '--allow-permissive-selinux' "$boot_audit"
grep -Fq -- '--allow-embedded-adb-key' "$image_audit"
grep -Fq -- '--allow-permissive-selinux' "$image_audit"
# shellcheck disable=SC2016
grep -Fq 'simg2img "$image_directory/$partition.img"' "$image_audit"
grep -Fq 'minimum_free_bytes' "$image_audit"
grep -Fq 'expanded_image_bytes' "$image_audit"
grep -Fq -- '--stay-bootloader is valid only for install' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'Phone remains in bootloader-fastboot for the next audited step.' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'fastbootd_slot_a_verified=true' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'slot A was not active before entering fastbootd' \
  "$script_directory/scripts/lineage-userspace"
# shellcheck disable=SC2016
grep -Fq 'echo "${partition}_a"' \
  "$script_directory/scripts/lineage-userspace"
# shellcheck disable=SC2016
grep -Fq '"$(fastbootd_partition_name "$partition")"' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'flash_partition vbmeta_a' "$keybound_helper"
grep -Fq 'flash_partition boot_a' "$keybound_helper"
grep -Fq 'embedded ADB key does not match this normal-user host key' "$keybound_helper"
grep -Fq 'expected exactly one device already in bootloader-fastboot' "$keybound_helper"
grep -Fq 'slot A is not active' "$keybound_helper"
grep -Fq -- '--allow-permissive-selinux is valid only for a private install' \
  "$keybound_helper"
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
# shellcheck disable=SC2016
grep -Fq 'flash boot_a "$output"' "$lineage_root"
grep -Fq 'No Zygisk, concealment or additional module was enabled.' "$lineage_root"
grep -Fq 'ro.system.build.fingerprint' "$lineage_root"
grep -Fq 'avbtool add_hash_footer' "$lineage_root"
# shellcheck disable=SC2016
grep -Fq 'flash vbmeta_a "$lineage_vbmeta"' "$lineage_unroot"
# shellcheck disable=SC2016
grep -Fq 'flash boot_a "$lineage_boot"' "$lineage_unroot"
grep -Fq 'ro.system.build.fingerprint' "$lineage_unroot"
grep -Fq 'Prefer' "$lineage_root_full"
grep -Fq 'ROM and hardware debugging' "$lineage_root_full"
if grep -Eq \
  'fastboot .*flash (system|system_ext|product|vendor|odm|dtbo|vbmeta_system|vbmeta_vendor)' \
  "$lineage_root" "$lineage_unroot"; then
  echo "Lineage root helpers can write outside the bootpair." >&2
  exit 1
fi
if grep -Eq \
  'fastboot .*(erase|format|delete-logical-partition|create-logical-partition|resize-logical-partition)' \
  "$lineage_root" "$lineage_unroot"; then
  echo "Lineage root helpers contain a destructive non-boot operation." >&2
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
