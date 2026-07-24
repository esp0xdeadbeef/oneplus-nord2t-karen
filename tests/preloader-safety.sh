#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
probe_script="$script_directory/scripts/probe-preloader"
gpt_script="$script_directory/scripts/read-gpt"

fail() {
  echo "Preloader safety check failed: $*" >&2
  exit 1
}

grep -Fq 'mtk gettargetconfig --skipwdt' "$probe_script"
grep -Fq 'mtk gpt --skipwdt' "$gpt_script"
# shellcheck disable=SC2016 # Match the literal safety gate in the helper.
grep -Fq 'cmp -s "$read_one/gpt.bin" "$read_two/gpt.bin"' "$gpt_script"
grep -Fq 'Raw logs, ME ID, SoC ID' "$gpt_script"

if grep -Eq \
  'mtk[[:space:]]+(w|wf|wl|wo|e|es|ess|da[[:space:]]+vbmeta)([[:space:]]|$)' \
  "$probe_script" "$gpt_script"; then
  echo "Unexpected MediaTek storage mutation in a read-only helper." >&2
  exit 1
fi

test_root="$(mktemp -d -t nord2t-preloader-safety.XXXXXXXX)"
cleanup() {
  rm -rf -- "$test_root"
}
trap cleanup EXIT

mock_bin="$test_root/bin"
mock_state="$test_root/state"
mock_output="$test_root/output"
mkdir -p "$mock_bin" "$mock_state"

cat >"$mock_bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$NORD2T_MOCK_STATE/adb.commands"
case "$*" in
  devices)
    printf 'List of devices attached\nTESTSERIAL\tdevice\n'
    ;;
  "-s TESTSERIAL shell getprop sys.boot_completed")
    echo 1
    ;;
  "-s TESTSERIAL shell getprop ro.product.model")
    echo CPH2399
    ;;
  "-s TESTSERIAL shell getprop ro.product.device")
    echo OP557AL1
    ;;
  "-s TESTSERIAL shell getprop ro.build.display.id")
    echo 'CPH2399_14.0.0.3001(EX01)'
    ;;
  "-s TESTSERIAL reboot edl")
    touch "$NORD2T_MOCK_STATE/rebooted"
    ;;
  "-s TESTSERIAL get-state")
    echo device
    ;;
  *)
    echo "Unexpected mocked adb command: $*" >&2
    exit 64
    ;;
esac
EOF

cat >"$mock_bin/mtk" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$NORD2T_MOCK_STATE/mtk.commands"
case "${1:-}" in
  gpt)
    [[ $# == 3 && "$2" == --skipwdt ]]
    echo "Status: Waiting for PreLoader VCOM, please reconnect mobile to brom mode"
    while [[ ! -e "$NORD2T_MOCK_STATE/rebooted" ]]; do
      sleep 0.01
    done
    mkdir -p "$3"
    dd if=/dev/zero of="$3/gpt.bin" bs=4096 count=1 status=none
    printf 'EFI PART' |
      dd of="$3/gpt.bin" bs=1 seek=512 conv=notrunc status=none
    cp "$3/gpt.bin" "$3/gpt_backup.bin"
    ;;
  reset)
    [[ $# == 2 && "$2" == --skipwdt ]]
    ;;
  *)
    echo "Unexpected mocked mtkclient command: $*" >&2
    exit 64
    ;;
esac
EOF
chmod 0700 "$mock_bin/adb" "$mock_bin/mtk"
mock_bash="$(command -v bash)"
sed -i "1s|.*|#!$mock_bash|" "$mock_bin/adb" "$mock_bin/mtk"

mock_path="$mock_bin:$PATH"
NORD2T_MOCK_STATE="$mock_state" PATH="$mock_path" \
  bash "$gpt_script" --yes --output "$mock_output" >"$test_root/stdout"

[[ -s "$mock_output/gpt.bin" ]] || fail "mocked primary GPT was not retained"
[[ -s "$mock_output/gpt_backup.bin" ]] ||
  fail "mocked backup GPT was not retained"
(
  cd "$mock_output"
  sha256sum -c SHA256SUMS >/dev/null
)
[[ "$(stat -c '%a' "$mock_output")" == 700 ]] ||
  fail "private GPT directory mode is not 0700"
[[ "$(stat -c '%a' "$mock_output/gpt.bin")" == 600 ]] ||
  fail "private GPT file mode is not 0600"

[[ "$(grep -c '^gpt --skipwdt ' "$mock_state/mtk.commands")" == 2 ]] ||
  fail "mocked workflow did not perform exactly two GPT reads"
[[ "$(grep -c '^reset --skipwdt$' "$mock_state/mtk.commands")" == 1 ]] ||
  fail "mocked workflow did not perform exactly one DA reset"
if grep -Evq '^(gpt --skipwdt .*/read-(one|two)|reset --skipwdt)$' \
  "$mock_state/mtk.commands"; then
  fail "mocked workflow issued an unexpected mtkclient command"
fi
[[ "$(grep -Fxc -- '-s TESTSERIAL reboot edl' "$mock_state/adb.commands")" == 1 ]] ||
  fail "mocked workflow did not request exactly one preloader reboot"
grep -Fq "Two byte-identical GPT reads passed" "$test_root/stdout"
grep -Fq "No UFS write, erase or format command was sent." "$test_root/stdout"

echo "Preloader safety checks passed."
