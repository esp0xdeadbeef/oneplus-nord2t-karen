#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
firmware_manifest="$repository_root/firmware/manifest.json"
partition_manifest="$repository_root/firmware/partitions-3001.json"

jq -e --slurpfile partitions "$partition_manifest" '
  .schemaVersion == 1
  and $partitions[0].schemaVersion == 2
  and (
    [.packages[] | select(.id == $partitions[0].sourcePackageId)]
    | length == 1
  )
  and ($partitions[0].partitions | length == 34)
  and (
    [$partitions[0].partitions[].name] | unique | length == 34
  )
  and all(
    $partitions[0].partitions[];
    (.size | type == "number" and . > 0)
    and (.sha256 | test("^[0-9a-f]{64}$"))
  )
  and (
    [$partitions[0].partitions[].name] | sort
  ) == (
    $partitions[0].profiles.stock | sort
  )
  and (
    $partitions[0].profiles.port == $partitions[0].profiles.stock
  )
  and (
    ($partitions[0].profiles.lineage | sort) == ["odm", "vendor"]
  )
  and (
    [$partitions[0].treePartitions[] as $name
      | $partitions[0].profiles.blobs | index($name)]
    | all(. != null)
  )
  and (
    [$partitions[0].profiles[][]
      | . as $name
      | [$partitions[0].partitions[].name] | index($name)]
    | all(. != null)
  )
' "$firmware_manifest" >/dev/null

echo "Firmware metadata checks passed."
