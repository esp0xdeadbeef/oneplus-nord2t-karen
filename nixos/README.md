<!-- SPDX-License-Identifier: MIT -->

# Karen NixOS bring-up

This directory is the build-only start of the Mobile NixOS product line. It
does not install an operating system, modify a boot image, invoke kexec or
write a phone partition.

The first implemented boundary is intentionally smaller than a bootable
rootfs:

```text
pinned .3001 boot image
  -> exact stock DTB
  -> canonical DTS
  -> reviewed source patches
  -> rebuilt DTB
  -> canonical round-trip and hash manifest
```

This makes extracted hardware knowledge reviewable without pretending that a
binary Linux 4.19 image can be converted into Linux 6.x.

## Current files

- `metadata.nix` binds the MT6893 family and Karen device facts.
- `families/mt6893/` records the bootstrap-kernel and DTB policy.
- `devices/oneplus-karen/` records the verified identity and boot-image
  layout.
- `tools/dtb-workspace` implements the non-destructive DTB transformation.
- `lib/mk-dtb-workspace.nix` exposes that transformation as a Nix derivation.
- `tools/kernel-config-audit` classifies the effective stock-kernel config.
- `families/mt6893/kernel/nixos-control.config` is the first source-kernel
  configuration fragment.
- `patches/` is the only intended home for reviewed source patches.

No real Karen DTB patch is included yet. There is not yet enough evidence for
a correct node change: the bootloader-applied DTBO and live flattened device
tree first need to be reconciled with the base DTB. Inventing a
`reserved-memory`, USB, display or ramoops node would be more dangerous than
leaving the patchset empty.

## Build the baseline

The root flake already derives the exact kernel, DTB and DTBO from the pinned
`.3001` OTA. The initial NixOS expression reuses that output without changing
the root flake:

```bash
nix build --impure --file ./nixos/default.nix karenDtbBaseline
jq . ./result/manifest.json
```

`karenDtbBaseline` always uses an empty patchset. The separately named target
below applies every `patches/dtb/*.patch` file in lexical order:

```bash
nix build --impure --file ./nixos/default.nix karenDtbPatched
```

The stock `Image.gz` contains an embedded effective kernel configuration after
decompression. Extract and classify it with:

```bash
nix build --impure --file ./nixos/default.nix karenKernelConfigAudit
jq . ./result/report.json
```

This reports stage-1, systemd, USB, storage, kexec, Binder and diagnostics
options as built-in, module, disabled or unknown. It is evidence rather than a
pass/fail claim: a module needed before switch-root must still be included in
the initrd, and some requirements depend on the eventual rootfs design.

The first effective `.3001` audit establishes:

- `CONFIG_KEXEC` is disabled and `CONFIG_KEXEC_FILE` is absent;
- `CONFIG_DEVTMPFS` and `CONFIG_FHANDLE` are disabled;
- RNDIS configfs, IPv4, ext4, F2FS, device mapper, overlayfs, Binder,
  binderfs and pstore support are built in.

The Magisk kexec module therefore cannot jump from the unmodified stock
kernel: root can install the userspace loader, but the required syscall was
compiled out. Kexec-first now means “before a NixOS partition install”, not
“before every persistent boot write”. The prerequisite is a source-built 4.19
Lineage control kernel with the tracked `nixos-control.config` fragment,
installed to one explicitly recoverable boot slot.

That source build now completes successfully with the official OnePlus kernel
and module trees, verified generated DCT inputs and the reviewed patchset.
Its effective config contains `CONFIG_KEXEC=y`, devtmpfs, file handles and the
requested cgroup controllers. The current build output remains a diagnostic
insecure-recovery image, so the next gate is secure key-bound Lineage
packaging, AVB pairing and a hardware boot—not more compiler reconstruction.
See the [firmware and driver blocker matrix](../docs/nixos-blockers.md).

## Non-persistent kexec stage 1

The root flake exposes an experimental cross-compiled ARM64 initramfs for the
first real kexec proof:

```bash
nix run .#nixos-kexec-initramfs -- ./result-nixos-kexec-initramfs
```

The build is rootless and can run on an x86_64 remote builder. It does not
contain device-unique data, Wi-Fi setup, a persistent root filesystem or
partition-writing tools. Its callback is disabled unless the kexec command
line explicitly includes `karen.nixos.callback=1`.

When enabled, stage 1 creates only a USB RNDIS link. The phone uses
`192.168.97.2/30` and calls back to l-esp at `192.168.97.1:9001`; this is a
dedicated USB subnet and is independent of the normal LAN address. Assigning
the host address to the newly created USB interface needs root on l-esp, but
building either artifact does not. The returned shell prints
`NIXOS_KEXEC_READY`, `/etc/os-release` and `uname -a` before becoming
interactive.

The host can be prepared before the interface exists by adding a
NetworkManager profile that matches only the fixed RNDIS host MAC:

```bash
nmcli connection add \
  type ethernet \
  con-name nord2t-nixos-kexec \
  ifname '*' \
  802-3-ethernet.mac-address 02:4B:41:52:45:4E \
  ipv4.method manual \
  ipv4.addresses 192.168.97.1/30 \
  ipv4.never-default yes \
  ipv4.dns '' \
  ipv6.method disabled \
  connection.autoconnect yes
```

On l-esp this is already installed. NetworkManager may request root or
PolicyKit authorization on another host. Remove it after testing with
`nmcli connection delete nord2t-nixos-kexec`.

The live bootloader-applied FDT is captured only immediately before the test
and stays on l-esp and the phone. It can contain device-unique values and MUST
NOT enter Git, the Nix store or s-tau. Loading and executing the candidate are
separate operations; a hard reboot returns to the installed Lineage boot
slot because stage 1 performs no persistent writes.

The result contains:

```text
base.dts
patched-source.dts
compiled.dts
patched-entry.dtb
patched.dtb
changes.patch
manifest.json
```

The `.3001` boot payload called `dtb` is itself an Android DT table v0 with
one FDT entry, rather than a raw FDT starting at byte zero. The workspace
detects and validates that wrapper, extracts exactly one entry and rebuilds
the same table format with `mkdtboimg`. This is an example of an appropriate
format-aware binary operation; hard-coding the observed entry offset would
not be.

The first normalized baseline contains a `/chosen` boot argument for
`ttyS0,921600n1`, but no `ramoops`, `pstore` or `simple-framebuffer` node.
Neither an externally reachable serial console nor a safe diagnostic memory
region may be inferred from that boot argument alone.

With an empty patch directory, `changes.patch` must be empty and the
decompiled tree must survive a compile/decompile round trip. The rebuilt DTB
does not need to be byte-identical: property ordering, padding and string-table
layout are encoding details. The canonical DTS must be identical.

Run the isolated fixture test with:

```bash
nix shell nixpkgs#android-tools nixpkgs#dtc nixpkgs#jq nixpkgs#patch \
  --command bash -c \
  'nixos/tests/dtb-workspace.sh && nixos/tests/kernel-config-audit.sh'

nix build --impure --file ./nixos/tests/default.nix dtbWorkspace
```

## Why not patch the images at fixed byte offsets?

The useful part of that proposal is the extraction methodology:

1. recover addresses, interrupts, clocks, power sequencing and firmware
   protocols from the old C sources, DTB/DTBO and live device;
2. compare how the same MediaTek subsystem changed in the 5.10, 6.1 and 6.6
   donors;
3. express the result as a small DTS or C source patch against the selected
   kernel;
4. compile, package, audit and test the candidate through kexec.

Applying those findings directly as byte replacements is not a general
forward-port mechanism:

- a DTB is a structured flattened tree with a header, structure block, string
  table, alignment and phandle references; changing one value can move later
  offsets;
- `Image.gz` is compressed linked machine code; its layout, relocations,
  compiler decisions, types and internal kernel APIs change between releases;
- kernel API shims need source-level types, locking, lifetime and subsystem
  integration and cannot be recovered by redirecting a few call addresses;
- a firmware compatibility shim can be valid, but it is a new source driver
  that presents current kernel interfaces while speaking the old firmware
  protocol;
- changing an authenticated boot payload invalidates its AVB hash/footer until
  a format-aware build step creates matching metadata.

Byte-exact operations remain appropriate for verification, copying an
unchanged component, fixed-format boot-image assembly and documented padding.
They are not used here to transplant drivers or bypass AVB.

## First real patches

Add changes one subsystem at a time:

1. capture the base DTB, stock DTBO and live flattened tree;
2. normalize and diff those three views;
3. add the smallest justified DTS patch under `patches/dtb/`;
4. add a source-kernel patch only in the dedicated kernel fork;
5. pin its commit here and build a kexec-only bundle;
6. keep NixOS rootfs installation disabled until the kexec matrix passes.

The first likely candidates are diagnostic visibility such as a proven
ramoops region or a verified bootloader framebuffer. Neither may be assigned
an address speculatively.
