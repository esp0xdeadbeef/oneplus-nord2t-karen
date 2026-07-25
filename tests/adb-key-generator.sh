#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d -t nord2t-adb-key-test.XXXXXXXX)"
cleanup() {
  rm -r -- "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM
chmod 700 "$temporary_directory"

test_home="$temporary_directory/home"
identity="$temporary_directory/age-identity.txt"
secret="$temporary_directory/test-adb-host-key.age"
key="$test_home/.android/adbkey"
output="$temporary_directory/output.txt"

install -d -m 0700 "$test_home"
age-keygen -o "$identity" >/dev/null 2>&1
chmod 600 "$identity"

HOME="$test_home" \
  bash "$script_directory/scripts/adb-key-generator" \
    --secret-file "$secret" \
    --age-key-file "$identity" \
    >"$output"

grep -Fxq "action=generated-new" "$output"
[[ -s "$secret" && -s "$key" && -s "$key.pub" ]]
[[ "$(stat -c %a "$key")" == 600 ]]
[[ "$(stat -c %a "$key.pub")" == 644 ]]
if grep -Eq 'PRIVATE KEY|AAAA[A-Za-z0-9+/]{40}' "$output"; then
  echo "ADB key generator exposed key material." >&2
  exit 1
fi

saved_key="$temporary_directory/saved-adbkey"
mv "$key" "$saved_key"
mv "$key.pub" "$temporary_directory/saved-adbkey.pub"

HOME="$test_home" \
  bash "$script_directory/scripts/adb-key-generator" \
    --secret-file "$secret" \
    --age-key-file "$identity" \
    >"$output"

grep -Fxq "action=restored-from-sops" "$output"
cmp -s "$saved_key" "$key"

other_key="$temporary_directory/other-adbkey"
HOME="$test_home" adb keygen "$other_key" >/dev/null 2>&1
chmod 600 "$other_key"
if HOME="$test_home" \
  bash "$script_directory/scripts/adb-key-generator" \
    --secret-file "$secret" \
    --key-file "$other_key" \
    --age-key-file "$identity" \
    >"$output" 2>&1; then
  echo "ADB key generator accepted a local/SOPS mismatch." >&2
  exit 1
fi
grep -Fq "SOPS and local ADB private keys differ" "$output"

automatic_home="$temporary_directory/automatic-home"
automatic_identity="$automatic_home/.config/sops/age/keys.txt"
automatic_secret="$temporary_directory/automatic-adb-host-key.age"
install -d -m 0700 "$automatic_home"
HOME="$automatic_home" \
  bash "$script_directory/scripts/adb-key-generator" \
    --secret-file "$automatic_secret" \
    --age-key-file "$automatic_identity" \
    >"$output"
grep -Fxq "action=generated-new" "$output"
grep -Fxq "age_identity=generated-local" "$output"
[[ "$(stat -c %a "$automatic_identity")" == 600 ]]

echo "ADB key generator checks passed."
