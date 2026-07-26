<!-- SPDX-License-Identifier: MIT -->

# Nix expression layout

The root `flake.nix` owns only pinned inputs, supported host systems and
top-level output wiring. Implementations live here:

- `packages/artifacts.nix` builds or verifies APKs, Magisk modules, GApps and
  stock firmware inputs;
- `packages/device-tools.nix` wraps stock extraction, audits and bounded
  root/flash helpers;
- `packages/lineage.nix` owns the Android FHS environment, Karen device-tree
  assembly, Robotnix configurations and Lineage image outputs;
- `packages/kernel/lineage.nix` exposes the pinned OnePlus Android kernel and
  module trees;
- `packages/kernel/nixos.nix` applies the control-kernel patchset and
  KEXEC/NixOS bootstrap config and builds the experimental cross-compiled
  NixOS stage-1 initramfs. It does not claim to provide a native mainline
  NixOS kernel;
- `apps.nix`, `checks.nix` and `dev-shell.nix` expose the corresponding flake
  outputs.

`packages/default.nix` is the only package-composition layer. Domain modules
return a private implementation scope plus a `public` attribute set. Adding a
helper to an internal scope therefore does not silently add a new public flake
output.
