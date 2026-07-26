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
userspace_preflight="$script_directory/scripts/preflight-lineage-userspace"

# shellcheck disable=SC2016
grep -Fq 'PRODUCT_ADB_KEYS := $(strip $(KAREN_DEBUG_ADB_KEYS))' "$device_makefile"
# shellcheck disable=SC2016
grep -Fq 'ifeq ($(KAREN_DEBUG_PERMISSIVE),true)' "$board_config"
grep -Fq 'BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive' "$board_config"
grep -Fq 'BOARD_KERNEL_CMDLINE += androidboot.slot_suffix=_a' "$board_config"
if grep -Fq 'TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT := true' "$board_config"; then
  echo "Karen recovery must not power-cycle its OLED during UI init." >&2
  exit 1
fi
grep -Fq 'ramdisk enables the OLED-breaking recovery init power-cycle' \
  "$boot_audit"
grep -Fq 'androidboot.slot_suffix=_a' "$boot_audit"
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
grep -Fq 'fastboot_variable is-logical:system_a' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'fastbootd exposed no writable slot-A system mapping' \
  "$script_directory/scripts/lineage-userspace"
# shellcheck disable=SC2016
grep -Fq 'echo "${partition}_a"' \
  "$script_directory/scripts/lineage-userspace"
# shellcheck disable=SC2016
grep -Fq '"$(fastbootd_partition_name "$partition")"' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'for partition in product system system_ext vendor odm' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'stage_stock_fastbootd_boot_chain' \
  "$script_directory/scripts/lineage-userspace"
# shellcheck disable=SC2016
grep -Fq '"$restore_directory/images/boot.img"' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq \
  "'dd if=/dev/block/by-name/super bs=1048576 count=4 2>/dev/null'" \
  "$userspace_preflight"
grep -Fq 'endswith("-cow")' "$userspace_preflight"
grep -Fq 'preflight_source=lineage-recovery' "$userspace_preflight"
grep -Fq -- '--allow-stale-cow' "$userspace_preflight"
grep -Fq -- '--cleanup-stale-cow' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'cleanup_audited_stale_cow_partitions' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'fastbootd_variable_with_retry snapshot-update-status' \
  "$script_directory/scripts/lineage-userspace"
# shellcheck disable=SC2016
grep -Fq 'fastboot_arguments=(-S 64M flash "$partition" "$image")' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'Fastbootd attested: userspace=yes, slot=a' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'android.hardware.boot-service.default_recovery' \
  "$script_directory/lineage/device/oneplus/karen/device.mk"
grep -Fq "BOARD_VENDOR_SEPOLICY_DIRS += \$(DEVICE_PATH)/sepolicy/vendor" \
  "$board_config"
grep -Fq '/dev/block/sdc1' \
  "$script_directory/lineage/device/oneplus/karen/sepolicy/vendor/file_contexts"
grep -Fq 'u:object_r:misc_block_device:s0' \
  "$script_directory/lineage/device/oneplus/karen/sepolicy/vendor/file_contexts"
grep -Fq '/dev/block/sdc68' \
  "$script_directory/lineage/device/oneplus/karen/sepolicy/vendor/file_contexts"
grep -Fq 'u:object_r:super_block_device:s0' \
  "$script_directory/lineage/device/oneplus/karen/sepolicy/vendor/file_contexts"
grep -Fq 'genfscon tmpfs /block/sdc68 u:object_r:super_block_device:s0' \
  "$script_directory/lineage/device/oneplus/karen/sepolicy/vendor/genfs_contexts"
grep -Fq 'system/bin/hw/android.hardware.boot-service.default_recovery' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'interface aidl android.hardware.boot.IBootControl/default' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'recovery does not label the concrete misc block device' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'recovery does not label the concrete super block device' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'compiled recovery policy does not label the tmpfs-backed super node' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'restorecon /dev/block/sdc68' \
  "$script_directory/lineage/device/oneplus/karen/rootdir/etc/init.recovery.mt6893.rc"
grep -Fq 'on boot' \
  "$script_directory/lineage/device/oneplus/karen/rootdir/etc/init.recovery.mt6893.rc"
grep -Fq 'on property:sys.usb.config=fastboot' \
  "$script_directory/lineage/device/oneplus/karen/rootdir/etc/init.recovery.mt6893.rc"
grep -Fq 'recovery does not apply the concrete super block label before fastbootd' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'recovery does not refresh the concrete super block label before starting services' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'recovery does not refresh the concrete super block label for fastbootd' \
  "$script_directory/scripts/audit-boot-image"
grep -Fq 'select_fastboot_device' \
  "$script_directory/scripts/lineage-keybound-adb"
grep -Fq 'expected one device in bootloader-fastboot after the image audits' \
  "$script_directory/scripts/lineage-keybound-adb"
# shellcheck disable=SC2016
grep -Fq 'run_fastboot delete-logical-partition "$partition"' \
  "$script_directory/scripts/lineage-userspace"
for stale_cow in \
  my_engineering_a-cow \
  my_heytap_a-cow \
  my_product_a-cow \
  my_stock_a-cow \
  odm_a-cow \
  product_a-cow \
  system_a-cow \
  system_ext_a-cow \
  vendor_a-cow; do
  grep -Fq "$stale_cow" "$userspace_preflight"
  grep -Fq "$stale_cow" "$script_directory/scripts/lineage-userspace"
done
if grep -Eq \
  '^[[:space:]]*(run_fastboot|fastboot([[:space:]]+-s[[:space:]]+"[^"]+")?)[[:space:]]+snapshot-update[[:space:]]+cancel' \
  "$userspace_preflight" "$script_directory/scripts/lineage-userspace"; then
  echo "Lineage userspace helpers must not cancel snapshots implicitly." >&2
  exit 1
fi
grep -Fq 'flash_partition vbmeta_a' "$keybound_helper"
grep -Fq 'flash_partition boot_a' "$keybound_helper"
grep -Fq 'embedded ADB key does not match this normal-user host key' "$keybound_helper"
grep -Fq 'embedded-adb-key.token' "$keybound_helper"
grep -Fq 'host-adb-key.token' "$keybound_helper"
grep -Fq -- '--stay-bootloader is valid only for a private install' \
  "$keybound_helper"
grep -Fq 'Phone remains in bootloader-fastboot for the recovery add-on step.' \
  "$keybound_helper"
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

if find "$script_directory/secrets" \
  -type f ! -name '*.age' \
  -print -quit 2>/dev/null |
  grep -q .; then
  echo "A non-SOPS file is present in the secrets directory." >&2
  exit 1
fi
for encrypted_secret in "$script_directory"/secrets/*.age; do
  [[ -e "$encrypted_secret" ]] || continue
  grep -Fq '"sops":' "$encrypted_secret" || {
    echo "A tracked .age file is not SOPS-encrypted." >&2
    exit 1
  }
done

echo "Package safety checks passed."
