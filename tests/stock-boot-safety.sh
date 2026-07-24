#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root_script="$script_directory/scripts/stock-root"
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

echo "Stock boot safety checks passed."
