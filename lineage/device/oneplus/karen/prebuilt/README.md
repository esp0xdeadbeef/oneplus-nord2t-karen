<!-- SPDX-License-Identifier: MIT -->

# Local bring-up inputs

`scripts/prepare-lineage` writes the verified `.3001` stock kernel, DTB and
DTBO here for an interactive Lineage checkout. The `.#karen-device-tree` Nix
derivation creates the same layout directly in `/nix/store`. In both cases the
inputs are reconstructed from the pinned stock OTA and checked against the
repository manifests.

The binary paths are deliberately ignored by Git and must not be published as
device-tree source. See `docs/lineage-port.md` for the exact commands and
ignored paths.

This is only the first recovery bring-up stage. An official-quality Lineage
port must build the GPL-2.0 kernel from the pinned OnePlus source and reproduce
the required device trees.
