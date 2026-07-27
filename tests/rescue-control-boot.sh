#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repository_root/scripts/rescue-control-boot"
temporary_directory="$(mktemp -d -t nord2t-rescue-control-boot-test.XXXXXXXX)"
trap 'rm -rf -- "$temporary_directory"' EXIT

fake_bin="$temporary_directory/bin"
rollback_directory="$temporary_directory/rollback"
rollback_pointer="$temporary_directory/rollback.path"
fastboot_log="$temporary_directory/fastboot.log"
mkdir -p "$fake_bin" "$rollback_directory"
chmod 0700 "$rollback_directory"
truncate -s 67108864 "$rollback_directory/boot_a.img"
chmod 0600 "$rollback_directory/boot_a.img"
(
  cd "$rollback_directory"
  sha256sum boot_a.img >SHA256SUMS
)
printf '%s\n' "$rollback_directory" >"$rollback_pointer"

mock_bash="$(command -v bash)"
printf '#!%s\n' "$mock_bash" >"$fake_bin/fastboot"
cat >>"$fake_bin/fastboot" <<'EOF'
set -euo pipefail

scenario="${FASTBOOT_SCENARIO:-success}"
log="${FASTBOOT_LOG:?}"

if [[ "${1:-}" == devices ]]; then
  if [[ "$scenario" == multiple ]]; then
    printf 'one\tfastboot\ntwo\tfastboot\n'
  else
    printf 'fake-device\tfastboot\n'
  fi
  exit 0
fi

[[ "${1:-}" == -s && "${2:-}" == fake-device ]]
shift 2
printf '%q ' "$@" >>"$log"
printf '\n' >>"$log"

if [[ "${1:-}" == getvar ]]; then
  variable=${2:?}
  case "$variable" in
    is-userspace)
      value=no
      [[ "$scenario" != fastbootd ]] || value=yes
      ;;
    product)
      value=k6893v1_64_k419
      ;;
    hw-revision)
      value=ca00
      ;;
    current-slot)
      value=a
      [[ "$scenario" != wrong-slot ]] || value=b
      ;;
    unlocked)
      value=yes
      ;;
    *)
      exit 1
      ;;
  esac
  printf '(bootloader) %s: %s\nOKAY\n' "$variable" "$value" >&2
  exit 0
fi

if [[ "${1:-}" == flash ]]; then
  [[ "$#" == 3 ]]
  [[ "$2" == boot_a ]]
  [[ "$3" == */rollback/boot_a.img ]]
  exit 0
fi

[[ "${1:-}" == reboot && "$#" == 1 ]]
EOF
chmod 0755 "$fake_bin/fastboot"

run_helper() {
  FASTBOOT_LOG="$fastboot_log" \
    FASTBOOT_SCENARIO="$1" \
    PATH="$fake_bin:$PATH" \
    bash "$helper" "$rollback_pointer" --wait 1 --yes
}

run_helper success
grep -Eq '^flash boot_a .*/rollback/boot_a\.img $' "$fastboot_log"
grep -Fxq 'reboot ' "$fastboot_log"
if grep -Eq '(^| )set_active( |$)|(^| )flash (boot_b|vendor|userdata)( |$)' \
  "$fastboot_log"; then
  echo 'Rescue helper attempted an operation outside boot_a.' >&2
  exit 1
fi

for refused_scenario in fastbootd wrong-slot multiple; do
  : >"$fastboot_log"
  if run_helper "$refused_scenario"; then
    echo "Rescue helper accepted unsafe scenario: $refused_scenario" >&2
    exit 1
  fi
  if grep -Fq 'flash ' "$fastboot_log"; then
    echo "Rescue helper flashed during unsafe scenario: $refused_scenario" >&2
    exit 1
  fi
done
