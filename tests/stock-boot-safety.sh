#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root_script="$script_directory/scripts/stock-root"
full_script="$script_directory/scripts/stock-root-full"
unroot_script="$script_directory/scripts/stock-unroot"
flake="$script_directory/flake.nix"

grep -Fq \
  'https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk' \
  "$flake"

for script in "$root_script" "$unroot_script"; do
  grep -Fq 'ro.product.model)" == CPH2399' "$script"
  grep -Fq 'ro.product.device)" == OP557AL1' "$script"
  grep -Fq 'CPH2399_14.0.0.3001(EX01)' "$script"
  grep -Fq \
    '7ad447405db4e74276395123c8029c67c63adc3fc6d82c4c180ae6c2e31882c0' \
    "$script"
  grep -Fq 'fastboot_variable unlocked' "$script"
  grep -Fq 'adb_bootloader_unlocked' "$script"
  grep -Fq 'androidboot.vbmeta.device_state=unlocked' "$script"
  grep -Fq "flash \"boot_\$current_slot\"" "$script"

  if grep -Eq \
    'fastboot([^[:alnum:]]|.*[[:space:]])(erase|format|flashing unlock|flashing lock)' \
    "$script"; then
    echo "Unsafe fastboot operation in $(basename "$script")" >&2
    exit 1
  fi

  if grep -Eq \
    'fastboot.*flash.*(bootloader|dtbo|frp|metadata|nvdata|nvram|persist|super|userdata|vbmeta|vendor_boot)' \
    "$script"; then
    echo "Unexpected flash target in $(basename "$script")" >&2
    exit 1
  fi
done

grep -Fq \
  'e0d32d2123532860f97123d927b1bb86c4e08e6fd8a48bfc6b5bee0afae9ebd5' \
  "$root_script"
grep -Fq "fastboot -s \"\$serial\" boot \"\$output\"" "$root_script"
grep -Fq 'Magisk did not change the stock ramdisk' "$root_script"
grep -Fq "[[ \"\$persist\" == true ]]" "$unroot_script"
grep -Fq 'fastboot_variable product)" == k6893v1_64_k419' "$unroot_script"
grep -Fq 'fastboot_variable hw-revision)" == ca00' "$unroot_script"
grep -Fq "[[ \"\$from_fastboot\" == true ]]" "$unroot_script"

for input in \
  'JingMatrix/Vector/releases/download/v2.0/Vector-v2.0-3021-Release.zip' \
  'AdAway/AdAway/releases/download/v6.1.4/AdAway-6.1.4-20241027.apk' \
  'HMA-V3.8.r499.3a346c0-release.apk' \
  'Shamiko-v1.2.5-414-release.zip'; do
  grep -Fq "$input" "$flake"
done

grep -Fq 'ro.product.model)" == CPH2399' "$full_script"
grep -Fq 'ro.product.device)" == OP557AL1' "$full_script"
grep -Fq 'CPH2399_14.0.0.3001(EX01)' "$full_script"
grep -Fq 'adb_bootloader_unlocked' "$full_script"
grep -Fq 'androidboot.vbmeta.device_state=unlocked' "$full_script"
grep -Fq 'REPLACE INTO settings' "$full_script"
grep -Fq 'magisk --denylist disable' "$full_script"
grep -Fq 'magisk --install-module' "$full_script"
grep -Fq 'org.adaway' "$full_script"
grep -Fq 'com.tsng.hidemyapplist' "$full_script"
if grep -Eq \
  'fastboot([^[:alnum:]]|.*[[:space:]])(erase|format|flash|flashing)' \
  "$full_script"; then
  echo "Unexpected direct fastboot operation in stock-root-full" >&2
  exit 1
fi

echo "Stock boot safety checks passed."
