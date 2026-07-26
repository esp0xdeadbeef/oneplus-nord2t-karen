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
lineage_system_fingerprint="$script_directory/scripts/read-lineage-system-fingerprint"
lineage_unroot="$script_directory/scripts/lineage-unroot"
owner_apk_signer="$script_directory/scripts/owner-sign-apk"
adaway_dependency_lock="$script_directory/gradle/adaway-deps.json"
artifact_packages="$script_directory/nix/packages/artifacts.nix"
device_tools_packages="$script_directory/nix/packages/device-tools.nix"
lineage_packages="$script_directory/nix/packages/lineage.nix"
nixos_kernel_packages="$script_directory/nix/packages/kernel/nixos.nix"
robotnix_device="$script_directory/lineage/robotnix-karen.nix"
runtime_audit="$script_directory/scripts/audit-lineage-runtime"
sops_config="$script_directory/.sops.yaml"
userspace_preflight="$script_directory/scripts/preflight-lineage-userspace"
vector_owner_build="$script_directory/scripts/vector-owner-build-intermediate"
vector_owner_patch="$script_directory/patches/vector/0003-build-accept-public-signing-certificate.patch"
vector_memory_patch="$script_directory/patches/vector/0004-build-raise-gradle-daemon-memory.patch"
vector_owner_sign="$script_directory/scripts/vector-owner-sign"
vector_signing_generator="$script_directory/scripts/vector-signing-key-generator"

# shellcheck disable=SC2016
grep -Fq 'PRODUCT_ADB_KEYS := $(strip $(KAREN_DEBUG_ADB_KEYS))' "$device_makefile"
# shellcheck disable=SC2016
grep -Fq 'ifeq ($(KAREN_DEBUG_PERMISSIVE),true)' "$board_config"
grep -Fq 'BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive' "$board_config"
grep -Fq 'BOARD_KERNEL_CMDLINE += androidboot.slot_suffix=_a' "$board_config"
# shellcheck disable=SC2016
grep -Fq 'NEED_KERNEL_MODULE_SYSTEM := true' "$board_config"
if grep -Fq 'TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT := true' "$board_config"; then
  echo "Karen recovery must not power-cycle its OLED during UI init." >&2
  exit 1
fi
grep -Fq 'ramdisk enables the OLED-breaking recovery init power-cycle' \
  "$boot_audit"
grep -Fq 'androidboot.slot_suffix=_a' "$boot_audit"
grep -Fq -- '--allow-embedded-adb-key' "$boot_audit"
grep -Fq -- '--allow-permissive-selinux' "$boot_audit"
grep -Fq -- '--expected-kernel-sha256' "$boot_audit"
grep -Fq -- '--allow-embedded-adb-key' "$image_audit"
grep -Fq -- '--allow-permissive-selinux' "$image_audit"
grep -Fq -- '--expected-kernel-sha256' "$image_audit"
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
# shellcheck disable=SC2016
grep -Fq 'is_userspace="$(fastboot_variable is-userspace || true)"' \
  "$script_directory/scripts/lineage-userspace"
grep -Fq 'fastboot:no | fastbootd:yes)' \
  "$script_directory/scripts/lineage-userspace"
if grep -Fq "awk -v mode=\"\$expected_mode\"" \
  "$script_directory/scripts/lineage-userspace"; then
  echo "Fastboot transport labels must not be interpreted as protocol modes." >&2
  exit 1
fi
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
grep -Fq \
  'allow system_server apk_data_file file execute' \
  "$script_directory/patches/vector/0001-sepolicy-allow-system-service-native-modules.patch"
if grep -Eq \
  '^[+].*(^|[[:space:]])permissive([[:space:]]|$)' \
  "$script_directory/patches/vector/0001-sepolicy-allow-system-service-native-modules.patch"; then
  echo "Vector HMA compatibility patch must not make a domain permissive." >&2
  exit 1
fi
grep -Fq 'androidSigningCertificateFile' "$vector_owner_patch"
grep -Fq 'CertificateFactory.getInstance("X.509")' "$vector_owner_patch"
grep -Fq \
  'org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -Dfile.encoding=UTF-8' \
  "$vector_memory_patch"
grep -Fq 'pkgs.unzip' "$artifact_packages"
if grep -Fq -- '-Dorg.gradle.jvmargs=-Xmx4g ' "$artifact_packages"; then
  echo "Space-separated Gradle JVM arguments must live in gradle.properties." >&2
  exit 1
fi
# shellcheck disable=SC2016
grep -Fq 'KAREN_VECTOR_SIGNING_CERTIFICATE_FILE="$certificate"' \
  "$vector_owner_build"
grep -Fq 'vector-module-owner-intermediate' "$vector_owner_build"
grep -Fq 'repository-root mirror' "$vector_owner_build"
grep -Fq 'nord2t-read-lineage-system-fingerprint' "$lineage_root"
grep -Fq 'nord2t-read-lineage-system-fingerprint' "$lineage_root_full"
for source_kernel_helper in \
  "$lineage_root" \
  "$lineage_root_full" \
  "$lineage_unroot" \
  "$keybound_helper" \
  "$userspace_preflight" \
  "$script_directory/scripts/lineage-userspace"; do
  grep -Fq -- '--expected-kernel-sha256' "$source_kernel_helper"
done
grep -Fq \
  'candidate kernel does not match the explicit reviewed SHA-256' \
  "$boot_audit"
grep -Fq 'nord2t-owner-sign-apk' "$lineage_root_full"
grep -Fq 'nord2t-owner-sign-apk' \
  "$script_directory/scripts/stock-root-full"
grep -Fq "debugfs" "$lineage_system_fingerprint"
grep -Fq "dump.erofs" "$lineage_system_fingerprint"
grep -Fq -- '--vector-module-sha256' "$lineage_root_full"
grep -Fq -- '--vector-module-sha256' \
  "$script_directory/scripts/stock-root-full"
if [[ "$(grep -R -Fch \
  'b66605a0cf2cdbac9ca9accc9e47edc203791d3374d59fed2fa11f5a654f8333' \
  "$lineage_root_full" \
  "$script_directory/scripts/stock-root-full" |
  awk '{ total += $1 } END { print total + 0 }')" -ne 2 ]]; then
  echo "Both full-root routes must pin the source-built generic Vector module." >&2
  exit 1
fi
if grep -Eq 'androidStore(File|Password)|androidKeyPassword' \
  "$vector_owner_build"; then
  echo "Remote Vector build helper references private signing attributes." >&2
  exit 1
fi
# shellcheck disable=SC2016
grep -Fq -- '--ks-pass "file:$store_password_file"' "$vector_owner_sign"
# shellcheck disable=SC2016
grep -Fq -- '--key-pass "file:$key_password_file"' "$vector_owner_sign"
grep -Fq '@APKSIGNER@ verify --print-certs' "$vector_owner_sign"
# shellcheck disable=SC2016
grep -Fq 'sha256sum "$apk"' "$vector_owner_sign"
# shellcheck disable=SC2016
grep -Fq -- '--ks-pass "file:$store_password_file"' "$owner_apk_signer"
# shellcheck disable=SC2016
grep -Fq -- '--key-pass "file:$key_password_file"' "$owner_apk_signer"
grep -Fq 'input APK is already signed' "$owner_apk_signer"
grep -Fq '@APKSIGNER@ verify --print-certs' "$owner_apk_signer"
grep -Fq \
  'git+https://github.com/AdAway/AdAway.git?rev=89dc7277f5bd539ba108c20a857aae6e93199856' \
  "$script_directory/flake.nix"
grep -Fq 'data = repositoryRoot + /gradle/adaway-deps.json;' \
  "$artifact_packages"
grep -Fq 'version = "8.9";' "$artifact_packages"
grep -Fq 'useBwrap = false;' "$artifact_packages"
jq -e 'type == "object" and length > 0' \
  "$adaway_dependency_lock" >/dev/null
if grep -Fq 'AdAway-6.1.4-20241027.apk' "$artifact_packages"; then
  echo "AdAway must be built from its pinned upstream source." >&2
  exit 1
fi
grep -Fq \
  'https://github.com/LineageOS/android_external_chromium-webview_prebuilt_arm64.git' \
  "$artifact_packages"
grep -Fq 'rev = "aca8d63899707c568d48c412e2c34a8c11c4dd12";' \
  "$artifact_packages"
grep -Fq 'hash = "sha256-xBjQHGb8+RYzgR08qzA/dEpG0p5G9CnctSGmk5oHMYw=";' \
  "$artifact_packages"
grep -Fq 'fetchLFS = true;' "$artifact_packages"
if [[ "$(grep -Fc 'webviewSource = lineageWebviewArm64;' \
  "$lineage_packages")" -ne 5 ]]; then
  echo "Every Karen Robotnix variant must use the pinned WebView source." >&2
  exit 1
fi
grep -Fq 'source.dirs."external/chromium-webview/prebuilt/arm64".src' \
  "$robotnix_device"
grep -Fq 'lib.mkForce webviewSource;' "$robotnix_device"
grep -Fq \
  'TARGET_KERNEL_CONFIG := k6893v1_64_k419_ab_nixos_control_defconfig' \
  "$board_config"
grep -Fq \
  'k6893v1_64_k419_ab_defconfig' \
  "$nixos_kernel_packages"
grep -Fxq 'CONFIG_KEXEC=y' \
  "$script_directory/nixos/families/mt6893/kernel/nixos-control.config"
grep -Fq "grep -Fxq 'CONFIG_KEXEC=y' \"\$effective_config\"" \
  "$lineage_packages"
grep -Fq 'kernel.config' "$lineage_packages"
grep -Fq 'nwpower_unsl_blacklist_reject(void)' "$nixos_kernel_packages"
grep -Fq 'oplus_match_modem_wakeup(void)' "$nixos_kernel_packages"
grep -Fq 'CONFIG_NC_EXTRA y' "$nixos_kernel_packages"
grep -Fq 'karen.nixos.callback=1' "$nixos_kernel_packages"
grep -Fq 'transport: "USB RNDIS only"' "$nixos_kernel_packages"
grep -Fq 'persistent_writes: false' "$nixos_kernel_packages"
grep -Fq '02:4b:41:52:45:4e' "$nixos_kernel_packages"
if grep -Eiq 'wpa_supplicant|wifi_password|wifi_ssid' \
  "$nixos_kernel_packages"; then
  echo "The stage-1 initramfs must not contain Wi-Fi credentials or setup." >&2
  exit 1
fi
grep -Fq 'lock_supp_level(unsigned int level)' \
  "$script_directory/nixos/patches/kernel/0004-oplus-fix-control-kernel-warnings.patch"
grep -Fq -- '-Wno-error=strict-prototypes' \
  "$script_directory/nixos/patches/kernel/0005-clang-tolerate-legacy-vendor-warnings.patch"
if grep -Fq -- '-Wno-error=implicit-int' \
  "$script_directory/nixos/patches/kernel/0005-clang-tolerate-legacy-vendor-warnings.patch"; then
  echo "Control-kernel implicit integer diagnostics must remain fatal." >&2
  exit 1
fi
grep -Fq 'static int oplus_misc_healthinfo_parse_dt(' \
  "$nixos_kernel_packages"
grep -Fq 'extern int sysctl_sched_impt_tgid;' \
  "$script_directory/nixos/patches/kernel/0006-clang-fix-control-kernel-types.patch"
grep -Fq 'DPMA_DRB_DATA_INFO("%p(%04d):"' \
  "$script_directory/nixos/patches/kernel/0006-clang-fix-control-kernel-types.patch"
grep -Fq '../../../../drivers/misc/mediatek/typec/tcpc/inc/tcpm.h' \
  "$script_directory/nixos/patches/kernel/0007-oplus-fix-lineage-kernel-include-paths.patch"
grep -Fq 'static int last_recharging_vol = 0;' \
  "$script_directory/nixos/patches/kernel/0008-oplus-fix-control-kernel-types.patch"
grep -Fq '#define Ptr2UINT32(p)   ((uint32_t)(uintptr_t)(p))' \
  "$script_directory/nixos/patches/kernel/0008-oplus-fix-control-kernel-types.patch"
grep -Fq 'static bool need_upload = true;' \
  "$script_directory/nixos/patches/kernel/0009-oplus-fix-vooc-upload-type.patch"
grep -Fq 'static bool ui_to_soc_jump_flag = false;' \
  "$script_directory/nixos/patches/kernel/0010-oplus-fix-debug-boolean-types.patch"
grep -Fq 'static bool flag = false;' \
  "$script_directory/nixos/patches/kernel/0010-oplus-fix-debug-boolean-types.patch"
grep -Fq "'static int stm8s_parse_fw_from_array('" \
  "$nixos_kernel_packages"
grep -Fq "'extern void Eeprom_DistortionParamsRead('" \
  "$nixos_kernel_packages"
grep -Fq \
  'source.dirs."kernel/oneplus/vendor/mediatek/kernel_modules".src' \
  "$robotnix_device"
grep -Fq 'source.dirs."kernel/oneplus/vendor/oplus".src' "$robotnix_device"
grep -Fq 'karen-stock-module-signing-certificate.x509.der' \
  "$device_tools_packages"
grep -Fq \
  '30ee2ffb56cefe69f1c6d0439b7c566fa6121f784ba90d80bfba212404f7000d' \
  "$device_tools_packages"
grep -Fq 'serial=9DFB3A7B9EEB1555' "$device_tools_packages"
grep -Fq \
  'CONFIG_SYSTEM_TRUSTED_KEYS="certs/karen-stock-module-signing.x509"' \
  "$nixos_kernel_packages"
# shellcheck disable=SC2016
grep -Fq 'modprobe --show-modversions "$module_path"' "$image_audit"
grep -Fq 'openssl cms' "$image_audit"
# shellcheck disable=SC2016
grep -Fq 'stock_vendor_module_abi=$module_abi_status' "$image_audit"
# shellcheck disable=SC2016
grep -Fq \
  'cp --reflink=auto "$kernel_object/Module.symvers" "$out/Module.symvers"' \
  "$lineage_packages"
# shellcheck disable=SC2016
grep -Fq \
  '"$kernel_object/include/config/kernel.release"' \
  "$lineage_packages"
grep -Fq \
  'path_regex: '"'"'^secrets/vector-signing-shared\.json\.age$'"'"'' \
  "$sops_config"
grep -Fq \
  'path_regex: '"'"'^secrets/vector-signing-private\.json\.age$'"'"'' \
  "$sops_config"
[[ "$(grep -Fc -- '- *l-portal-deadbeef' "$sops_config")" -eq 2 ]]
[[ "$(grep -Fc -- '- *l-esp-deadbeef' "$sops_config")" -eq 3 ]]
[[ "$(grep -Fc -- '- *s-tau-deadbeef' "$sops_config")" -eq 1 ]]
for signing_attribute in \
  androidStoreFile \
  androidStorePassword \
  androidKeyAlias \
  androidKeyPassword; do
  grep -Fq "$signing_attribute" "$vector_signing_generator"
done
# shellcheck disable=SC2016
grep -Fq -- '-storepass:file "$store_password_file"' \
  "$vector_signing_generator"
# shellcheck disable=SC2016
grep -Fq -- '-keypass:file "$key_password_file"' \
  "$vector_signing_generator"
if grep -Eq -- '-Pandroid(Store|Key)(File|Password|Alias)' \
  "$artifact_packages" "$lineage_packages" "$nixos_kernel_packages"; then
  echo "Vector private signing attributes must not enter a Nix derivation." >&2
  exit 1
fi
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

remote_builder_document="$script_directory/docs/remote-builder.md"
# shellcheck disable=SC2016
grep -Fq 'Nothing in this repository requires `s-tau`.' \
  "$remote_builder_document"
grep -Fq 'full LineageOS builds exhausted the memory' \
  "$remote_builder_document"
if grep -R -n -F \
  --include='*.md' \
  --exclude='remote-builder.md' \
  's-tau' \
  "$script_directory/README.md" \
  "$script_directory/docs"; then
  echo "Machine-specific s-tau references must be centralized in remote-builder.md." >&2
  exit 1
fi

echo "Package safety checks passed."
