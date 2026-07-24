#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
privacy_script="$script_directory/scripts/nord2t-privacy"

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

echo "Package safety checks passed."
