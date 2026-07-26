#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d -t karen-dtb-workspace-test.XXXXXXXX)"
cleanup() {
  chmod -R u+rwX -- "$temporary_directory" 2>/dev/null || true
  rm -rf -- "$temporary_directory"
}
trap cleanup EXIT

cat >"$temporary_directory/input.dts" <<'EOF'
/dts-v1/;

/ {
	compatible = "oneplus,karen";
	model = "Karen test fixture";

	chosen {
		bootargs = "fixture=base";
	};
};
EOF

dtc -q -I dts -O dtb \
  -o "$temporary_directory/input.dtb" \
  "$temporary_directory/input.dts"
input_sha256="$(sha256sum "$temporary_directory/input.dtb" | cut -d' ' -f1)"

mkdir "$temporary_directory/no-patches"
"$script_directory/tools/dtb-workspace" \
  "$temporary_directory/input.dtb" \
  "$temporary_directory/no-patches" \
  "$temporary_directory/baseline"

jq -e \
  --arg inputSha256 "$input_sha256" \
  '
    .schemaVersion == 1 and
    .inputFormat == "raw-fdt" and
    .entryCount == 1 and
    .inputSha256 == $inputSha256 and
    .patches == [] and
    .inPlaceBinaryPatch == false
  ' \
  "$temporary_directory/baseline/manifest.json" \
  >/dev/null
[[ ! -s "$temporary_directory/baseline/changes.patch" ]]

mkdtboimg create \
  "$temporary_directory/input-table.dtb" \
  --page_size=2048 \
  --version=0 \
  "$temporary_directory/input.dtb"
table_sha256="$(
  sha256sum "$temporary_directory/input-table.dtb" |
    cut -d' ' -f1
)"
mkdir "$temporary_directory/table-patches"
"$script_directory/tools/dtb-workspace" \
  "$temporary_directory/input-table.dtb" \
  "$temporary_directory/table-patches" \
  "$temporary_directory/table-baseline"
jq -e \
  --arg inputSha256 "$table_sha256" \
  '
    .inputFormat == "android-dt-table-v0" and
    .entryCount == 1 and
    .inputSha256 == $inputSha256 and
    .patches == []
  ' \
  "$temporary_directory/table-baseline/manifest.json" \
  >/dev/null
mkdtboimg dump \
  "$temporary_directory/table-baseline/patched.dtb" \
  >/dev/null

mkdir "$temporary_directory/patches"
cat >"$temporary_directory/patches/0001-change-fixture-bootargs.patch" <<'EOF'
--- a/karen.dts
+++ b/karen.dts
@@ -1 +1 @@
-		bootargs = "fixture=base";
+		bootargs = "fixture=patched";
EOF

"$script_directory/tools/dtb-workspace" \
  "$temporary_directory/input.dtb" \
  "$temporary_directory/patches" \
  "$temporary_directory/patched"

grep -Fq 'bootargs = "fixture=patched";' \
  "$temporary_directory/patched/compiled.dts"
jq -e \
  '
    (.patches | length) == 1 and
    .patches[0].name == "0001-change-fixture-bootargs.patch" and
    .inputSha256 != .outputSha256 and
    .inPlaceBinaryPatch == false
  ' \
  "$temporary_directory/patched/manifest.json" \
  >/dev/null
[[ "$(sha256sum "$temporary_directory/input.dtb" | cut -d' ' -f1)" == \
  "$input_sha256" ]]

if "$script_directory/tools/dtb-workspace" \
  "$temporary_directory/input.dtb" \
  "$temporary_directory/no-patches" \
  "$temporary_directory/baseline" \
  >/dev/null 2>&1; then
  echo "DTB workspace unexpectedly overwrote an existing output." >&2
  exit 1
fi

echo "NixOS DTB workspace tests passed."
