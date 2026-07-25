<!-- SPDX-License-Identifier: MIT -->

# Mobile NixOS feature plan

Checked against the current UBports and Mobile NixOS documentation on
2026-07-25.

## Decision

Mobile NixOS development for `CPH2399` / `karen` belongs in this repository as
a second, explicitly separated product line. Do not create a separate primary
Karen repository and do not rename or discard the existing LineageOS work.

This repository is already the canonical owner of the physical-device
contract:

- the exact `CPH2399_14.0.0.3001(EX01)` firmware input and partition hashes;
- the verified stock kernel, DTB and DTBO;
- the boot-header, partition, dynamic-partition, virtual A/B and AVB layout;
- the `CPH2399` and `OP557AL1` device-identity gates;
- the bounded stock restore and bootloader recovery procedures;
- the image audits and tested rollback order.

Duplicating those facts and safety fixes across two repositories would create
avoidable drift around hardware writes. The repository name is OS-neutral, so
the intended model is:

```text
oneplus-nord2t-karen
├── shared firmware, layout, audits and rollback
├── LineageOS product integration
└── Mobile NixOS product integration
```

A short-lived feature branch is useful during development. Permanent
`lineage` and `nixos` branches are not: shared device and safety changes must
remain on one main line.

## End state and first success criterion

The intended end state is a full NixOS host operating system, not a rescue
shell or a Nix package environment inside Android:

```text
NixOS host
├── systemd as PID 1
├── NixOS networking, storage, updates and user sessions
├── Wayland and the selected mobile shell
├── native Nix packages
└── containerized LineageOS hardware adaptation
    ├── matching vendor libraries and HALs
    ├── Binder services
    ├── graphics / Hardware Composer
    ├── audio HAL
    ├── radio / IMS
    └── camera HAL
```

The LineageOS environment is a compatibility shim beneath NixOS services. It
does not own the host boot, PID 1, NixOS configuration or update lifecycle.
Both environments necessarily share the running Linux kernel; the container
does not bring or boot a second Android kernel.

The first NixOS result is deliberately headless:

```text
rooted LineageOS control system
  -> kexec from Magisk
  -> pinned stock kernel and DTB
  -> Mobile NixOS stage-1 initrd
  -> NixOS root filesystem
  -> systemd
  -> USB gadget networking
  -> authenticated SSH
```

Initial success means that PID 1 is running, `/nix/store` is available and the
phone is reachable through an explicitly authenticated USB connection.
Display, touch, audio, modem, camera, suspend and a mobile shell are not part
of this first gate. Native boot through the OnePlus bootloader follows only
after the same userspace has survived repeatable kexec tests.

The existing LineageOS result remains the known-good control. It demonstrates
that the boot chain, stock kernel, DTB, firmware and Android vendor adaptation
can operate the hardware. It does not prove that the same kernel can run a
current NixOS userspace or that Android HALs are directly usable by glibc
programs.

## Why this is not merely a LineageOS userspace replacement

The
[UBports porting introduction](https://docs.ubports.com/en/latest/porting/introduction/Intro.html)
describes an Android-derived Linux port as three distinct layers: a Linux
rootfs, a device-specific Halium adaptation and Android-version-specific
vendor blobs. It also warns that real ports are iterative and device-specific.

LineageOS proves the combination of the Android kernel, Binder services,
Android framework, proprietary userspace libraries and vendor HALs. NixOS
normally uses glibc and systemd and cannot call bionic-linked Android HALs as
ordinary native libraries. `libhybris`, Halium or an Android container may
eventually bridge selected services, but that is a separate compatibility
milestone rather than a property supplied automatically by Mobile NixOS.

Therefore the first port must avoid assuming that graphics, audio, radio or
camera support follows from the successful LineageOS boot.

## Repository layout

Add the NixOS work without moving or refactoring the working LineageOS path:

```text
nixos/
  default.nix
  device.nix
  configuration.nix
  stage-1.nix
  rootfs.nix
  kexec-bundle.nix
  boot-image.nix
  lineage-container.nix
  README.md

docs/
  feature-nixos.md

scripts/
  audit-nixos-kexec
  preflight-nixos-kexec
  audit-nixos-images
  preflight-nixos
  nixos-userspace
```

`lineage-container.nix` records the intended boundary from the start, but the
container must not be activated until the native host reaches systemd and
authenticated USB access without it.

Keep the existing firmware manifests and extraction paths shared. Extract a
new `device/` or `common/` Nix module only after LineageOS and NixOS actually
need the same declarative value and the extraction can be made without
destabilizing the proven LineageOS build.

The first planned flake interface is:

```bash
nix build .#karen-nixos-initrd
nix build .#karen-nixos-rootfs
nix build .#karen-nixos-kexec-bundle
nix build .#karen-nixos-boot
nix run .#audit-nixos-kexec -- ./result
nix run .#preflight-nixos-kexec -- ./result
nix run .#audit-nixos-images -- ./result
nix run .#preflight-nixos -- ./result ./result-stock-restore
nix run .#nixos-userspace -- install ./result ./result-stock-restore
nix run .#nixos-userspace -- restore ./result-stock-restore
```

These names are reserved design targets, not currently implemented outputs.
Do not change the existing default package, app or LineageOS outputs merely by
adding the NixOS product.

## Mobile NixOS integration boundary

Pin Mobile NixOS as an upstream source and use it for its NixOS module system,
stage-1 initrd and generated root filesystem. Do not vendor a complete mutable
Mobile NixOS checkout into this repository.

Mobile NixOS keeps device adaptations under `devices/<identifier>` and asks
completed ports to be proposed by pull request:

- [Mobile NixOS getting started](https://mobile.nixos.org/getting-started.html)
- [Mobile NixOS device porting guide](https://mobile.nixos.org/porting-guide.html)
- [Contributing to Mobile NixOS](https://mobile.nixos.org/contributing.html)

The current `oneplus-enchilada` port is useful for understanding the module
shape and the separate boot/rootfs outputs. It is not a safe installation
template for Karen. That port uses the mainline SDM845 family and its
instructions deliberately erase both DTBO slots. Karen instead starts with
the exact `.3001` MediaTek kernel and preserves the verified stock DTBO:

- [Mobile NixOS OnePlus 6 device page](https://mobile.nixos.org/devices/oneplus-enchilada.html)
- [OnePlus 6 device definition](https://github.com/mobile-nixos/mobile-nixos/blob/development/devices/oneplus-enchilada/default.nix)

## Karen-specific boot image

Do not directly expose Mobile NixOS'
`outputs.android-fastboot-images` as a Karen installer.

The current generic Mobile NixOS
[Android boot-image builder](https://github.com/mobile-nixos/mobile-nixos/blob/development/modules/system-types/android/bootimg.nix)
passes the traditional base, kernel, ramdisk, tags and page-size values to
`mkbootimg`, but does not pass the header-v2 and separate-DTB arguments needed
by the verified Karen layout.

Karen requires:

- Android boot header version 2;
- a 64 MiB boot partition;
- 2 KiB pages;
- the verified kernel, ramdisk, tags and DTB offsets;
- the exact stock kernel and DTB during initial bring-up;
- an audited AVB relationship with the selected boot slot.

Those values are currently recorded in
`lineage/device/oneplus/karen/BoardConfig.mk` and verified by the existing boot
audit. The NixOS path must build its own header-v2 boot image around the Mobile
NixOS initrd and then independently verify every structural field against the
pinned stock image.

The generic Mobile NixOS A/B fastboot script may write `boot` with
`--slot=all`, while leaving the rootfs as a separate manual operation. It does
not know Karen's complete AVB chain, dynamic-partition allocation, device gates
or stock rollback bundle. That generic script must therefore not be used
directly during bring-up.

A/B itself is not forbidden. Full NixOS should ultimately own a deliberate,
tested A/B installation and update cycle, including both boot slots when that
design is proven. The progression is:

1. kexec without persistent partition changes;
2. one explicitly selected boot slot with an exact restore path;
3. repeatable boot, rollback and slot-failure tests;
4. a Karen-specific A/B installer and updater that may write both slots and
   their matching AVB metadata as one audited transaction.

The rule is therefore “no unwrapped generic `--slot=all`”, not “NixOS may
never use both slots”.

The tested loader also cannot be assumed to support temporary
`fastboot boot`: a complete transfer previously returned to the running slot
with boot reason `lk_crash`. A transfer is not evidence that an image
executed. Any NixOS boot probe must use an explicitly documented, reversible
slot procedure after a complete preflight.

## Kernel feasibility audit

The initial port reuses the verified `.3001` stock kernel. This is a
bootstrapping choice, not an upstream-quality endpoint. Before building a
flash candidate, capture or extract the effective kernel configuration and
audit at least:

- `CONFIG_DEVTMPFS` and `CONFIG_DEVTMPFS_MOUNT`;
- tmpfs and the filesystem required for the selected rootfs;
- Unix sockets and `devpts`;
- namespaces needed by the selected userspace;
- cgroups and the interfaces required by the pinned systemd version;
- loop devices if the rootfs design uses them;
- overlayfs if the rootfs design uses it;
- USB gadget and configfs support for the selected network function;
- storage, device-mapper and crypto support needed before switch-root;
- F2FS and ext4 as applicable;
- Binder and binderfs only for a later Android compatibility layer;
- loadable module availability and the firmware search paths used in stage 1.

Classify each requirement as built-in, module, absent or not needed. A module
needed before mounting the real root must be included in stage 1 together with
its dependency and firmware closure.

The published OnePlus MT6893 source build remains independently blocked by
the missing `vendor/oplus` source layer. NixOS bootstrapping must not weaken
that fail-closed source-kernel assessment or present the prebuilt stock kernel
as a reproducible source build.

## Kernel source map and fork strategy

The absence of a complete MT6893 device tree from upstream Linux does not mean
that the only public MT6893 material is OnePlus's incomplete 4.19 publication.
Older MediaTek and OPlus-derived Android kernel trees contain substantial
source that can be used as a donor and as protocol documentation.

### Public MT6893 donor BSP

Pin the `RKSU` branch of
[`lijilong34/android_kernel_4.14_MT6853`](https://github.com/lijilong34/android_kernel_4.14_MT6853/tree/bd916df705eb0bb434ef26a59f39dc178b868287)
at commit `bd916df705eb0bb434ef26a59f39dc178b868287` when using it as
evidence. Despite the repository name and its support for several Oppo and
Realme products, that snapshot contains hundreds of MT6893-specific paths,
including:

- an
  [`mt6893.dts`](https://github.com/lijilong34/android_kernel_4.14_MT6853/blob/bd916df705eb0bb434ef26a59f39dc178b868287/arch/arm64/boot/dts/mediatek/mt6893.dts)
  of more than 8,000 lines and a `k6893v1_64` reference-board tree;
- M4U / IOMMU, CMDQ, USB PHY and storage implementations;
- display, DSI, DDP and framebuffer code;
- camera CCU, mailbox, sensor and calibration code;
- CPU and GPU frequency management, DVFS, thermal and power data.

A direct source comparison with the pinned OnePlus Android 14 kernel commit
`a5cdca1a88dc328a44dee724193830254fc551da` establishes common MediaTek BSP
ancestry rather than an accidental shared filename:

- the donor
  [`mt6893_battery_table.dtsi`](https://github.com/lijilong34/android_kernel_4.14_MT6853/blob/bd916df705eb0bb434ef26a59f39dc178b868287/arch/arm64/boot/dts/mediatek/bat_setting/mt6893_battery_table.dtsi)
  is line-for-line identical to the
  [OnePlus version](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893/blob/a5cdca1a88dc328a44dee724193830254fc551da/arch/arm64/boot/dts/mediatek/bat_setting/mt6893_battery_table.dtsi);
- the two `helio-dvfsrc-mt6893.c` implementations are nearly identical;
- the large donor and OnePlus `mt6893.dts` files share extensive blocks.

This materially reduces the amount of clean-room reconstruction that may be
required. The donor can reveal register maps, interrupts, memory layouts,
mailbox formats, firmware interaction and power sequencing missing from the
published OnePlus tree.

It is not automatically Karen-correct or Linux-6.x-ready. The tree includes
multiple products, board revisions and root-related changes. Some MT6893
sources inherit MT6885 names and assumptions, and code present in a tree may
not have been enabled in the shipped configuration. Validate every imported
fact against the `.3001` live device, resolved DTB, OnePlus 4.19 source and
runtime traces. Preserve all GPL notices and history, and audit provenance
before copying code rather than merging the complete donor branch.

Use the four sources with distinct authority:

| Source | Authority | Intended use |
| --- | --- | --- |
| Stock `.3001` kernel, resolved DTB and traces | Shipped Karen behavior | Ground truth for addresses, enabled hardware, protocols and sequencing |
| OnePlus Android 14 kernel 4.19 | Newest published Nord 2T source | Device-specific delta and first source-kernel reconstruction target |
| Pinned MediaTek/OPlus 4.14 donor | Older but more complete BSP evidence | Recover missing implementations and understand hardware contracts |
| Upstream Linux 6.x and adjacent MediaTek SoCs | Current kernel interfaces | Native subsystem design and forward-port destination |

For a 6.x port, use the older source as executable hardware documentation.
Bring up one subsystem at a time with an existing upstream driver where
possible, add MT6893 data and quirks, and port vendor code only where no native
implementation exists. Preserve the old Android userspace UAPI only where the
LineageOS compatibility container needs it; do not build a kernel-wide
emulation of Linux 4.19 internals.

### Fork decision

Create a fork of
[`OnePlusOSS/android_kernel_oneplus_mt6893`](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893)
when source-kernel work starts. Base its Karen branch on
`oneplus/mt6893_14_14.0.0_nord_2t_5g` at
`a5cdca1a88dc328a44dee724193830254fc551da`. This is the primary vendor-kernel
fork for:

- reconstructing or replacing the missing `vendor/oplus` dependencies;
- enabling and testing kexec where the hardware and effective configuration
  permit it;
- retaining the exact Android 14 UAPI and firmware relationship;
- producing a reproducible 4.19 control kernel before attempting broad
  forward ports.

Do not use the 4.14 donor as the primary fork. Keep its exact commit as a
read-only Git remote or pinned source input and import only reviewed,
attributed pieces. An archival fork is reasonable to preserve availability,
but development should not inherit its unrelated device history and RKSU
changes.

Do not evolve the OnePlus 4.19 fork into 6.x through a giant version merge.
When the first 6.x kexec experiments begin, create a separate fork or patch
stack based on the selected supported upstream Linux LTS. Keep MT6893 and
Karen commits reviewable by subsystem and pin the tested commit from this
integration repository. A Mobile NixOS fork is needed only when the cleaned
device module is ready to propose upstream.

The repository boundaries are therefore:

```text
oneplus-nord2t-karen
  integration, NixOS configuration, image audits and hardware safety

fork: OnePlusOSS/android_kernel_oneplus_mt6893
  reproducible vendor 4.19 control kernel and Android compatibility work

pinned donor: lijilong34/android_kernel_4.14_MT6853
  source archaeology only

later fork: upstream Linux LTS
  native 6.x MT6893 and Karen support

later fork: mobile-nixos/mobile-nixos
  upstreamable Karen device module only
```

## Kexec-first strategy

Before writing a NixOS boot image to either slot, use a rooted LineageOS
control installation with Magisk to test the second kernel and initrd through
kexec.

The [`evdenis/kexec`](https://github.com/evdenis/kexec) Magisk module installs
a static `kexec-tools` binary into `/system/bin` through Magisk's systemless
overlay. It supplies userspace tooling only. It does not add the kexec syscall
or device-specific shutdown support to the running kernel.

The published
[`k6893v1_64_k419_defconfig`](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893/blob/a5cdca1a88dc328a44dee724193830254fc551da/arch/arm64/configs/k6893v1_64_k419_defconfig)
does not list `CONFIG_KEXEC`, `CONFIG_KEXEC_FILE` or `CONFIG_CRASH_DUMP`.
OnePlus's ARM64
[Kconfig](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893/blob/a5cdca1a88dc328a44dee724193830254fc551da/arch/arm64/Kconfig#L868)
does contain the classic `kexec_load` implementation, but it is an optional
kernel setting. This makes the effective `.3001` kernel configuration the
first hard gate. Magisk root and the module cannot compensate if
`CONFIG_KEXEC` is absent.

### Kexec gates

Establish each gate independently:

1. Extract the effective config from the running kernel, `/proc/config.gz` or
   the pinned stock kernel and record whether `CONFIG_KEXEC=y`.
2. Confirm the syscall exists and distinguish “unsupported” from a Magisk or
   SELinux denial.
3. Pin the exact GPL-2.0 `evdenis/kexec` source or release and verify its hash;
   do not resolve `latest` during a test.
4. Verify that the ARM64 tool accepts the intended kernel format, initrd,
   command line and DTB.
5. Load and unload a harmless candidate without executing it.
6. Execute an initrd-only diagnostic candidate with no writable rootfs.
7. Repeat cold-return recovery to the installed LineageOS control system.
8. Add the NixOS rootfs and systemd only after the diagnostic initrd is
   observable.

The load/unload gate should be represented separately from execution. A
successful `kexec -l` proves that the syscall and loader accepted the
artifacts; it does not prove that `kexec -e` can quiesce MediaTek hardware or
that the second kernel will start.

The kexec bundle must contain and hash:

- the exact candidate kernel in the format accepted by the ARM64 loader;
- the Mobile NixOS initrd;
- the exact DTB passed to kexec;
- the reviewed second-kernel command line;
- a manifest tying all four artifacts to the `.3001` and Nix inputs.

Do not blindly pass the base DTB extracted from `boot.img`. The OnePlus
bootloader normally applies DTBO and may fix up the tree before the first
kernel starts. Compare the boot DTB, stock DTBO and live flattened device tree
and determine which fully resolved DTB the second kernel requires.

The first executable bundle may keep the complete diagnostic userspace in a
large initrd. Kexec loads that initrd from Android RAM and is not constrained
by the 64 MiB boot partition, so this can prove a minimal NixOS/systemd closure
without first assigning a persistent rootfs partition. Memory use and the
exact closure size must still be audited.

Kexec is a rapid, recoverable experiment path because it leaves boot, vbmeta
and logical partitions untouched. It is not risk-free: a device-driver
shutdown failure can still hang the phone, and the warm hardware state differs
from a bootloader cold boot. A successful kexec result is therefore necessary
bring-up evidence, not proof that the final native boot image works.

### Kexec test matrix

Do not reduce kexec validation to one successful jump. Record the input hashes,
control-system state and observable result for at least:

- tool execution and syscall detection without a loaded candidate;
- load followed by unload, with no jump;
- the exact stock kernel plus a tiny diagnostic initrd;
- the exact stock kernel plus the Mobile NixOS stage-1 initrd;
- a minimal all-in-initrd NixOS/systemd target;
- the audited live DTB versus any reconstructed DTB candidate;
- reviewed and reused command-line variants;
- USB connected directly to the laptop and USB disconnected;
- screen awake and screen blanked before the jump;
- radios enabled and airplane mode before the jump;
- orderly Android service shutdown versus the minimum required shutdown set;
- repeated jump, forced-reset and cold-return cycles.

Collect second-kernel progress through authenticated USB where possible and
through pstore/ramoops when the kernel exposes it. A black screen, USB
disconnect or automatic reset must be classified as a specific failed gate,
not as evidence that the candidate booted.

## Root filesystem placement

Do not choose `userdata`, `system` or another logical partition merely because
another device port uses it.

The rootfs location must be selected only after a read-only audit establishes:

- exact target size and filesystem support;
- whether the boot initrd can discover and mount it;
- the effect on F2FS encryption and factory reset;
- the effect on dynamic-partition metadata and available super space;
- the precise install and stock-restore write set;
- whether recovery and fastbootd can restore it without naming an OPlus,
  calibration, radio or persistent partition.

Flashing a rootfs to `userdata` destroys its contents. Reallocating a standard
logical partition changes the current stock/LineageOS layout and rollback
assumptions. Neither action belongs in the first initrd-only experiment.

## Staged bring-up

### 0. Build-only feasibility

1. Pin a known-good Mobile NixOS and Nixpkgs revision.
2. Audit the stock kernel configuration.
3. Generate a Mobile NixOS stage-1 initrd without a GUI.
4. Build and audit a kexec bundle without installing it.
5. Independently assemble a Karen header-v2 boot image for the later native
   boot phase.
6. Verify size, header, offsets, kernel, DTB, ramdisk and AVB metadata.
7. Produce no flash script until the image audit and exact restore set exist.

### 1. Kexec load and unload

From explicitly rooted LineageOS with Magisk, prove tool installation, syscall
availability and SELinux behavior. Load and unload an audited diagnostic
candidate without executing it. This phase makes no persistent partition
write.

### 2. Kexec stage-1 USB access

Execute only far enough to prove second-kernel execution, initrd execution and
a USB transport. Prefer USB gadget networking and key-bound SSH. A forced
reboot must return to the installed LineageOS control system.

The documented `mobile.boot.stage-1.ssh.enable` path currently permits blank
root login without a password or SSH key. Do not enable it unchanged. Model
the authentication gate on the repository's host-bound ADB approach and keep
private key material outside Git.

### 3. NixOS root and systemd through kexec

After stage 1 is observable:

1. mount the selected rootfs read-only first;
2. prove switch-root;
3. prove systemd reaches a bounded target;
4. prove `/nix/store` integrity;
5. enable authenticated USB networking in stage 2;
6. test orderly shutdown and reboot before adding desktop services.

### 4. Native boot and A/B lifecycle

After repeatable kexec boots, assemble and audit the native header-v2
`boot.img`. Test one selected slot with its exact AVB and stock restore pair.
Only after repeated native boot, rollback and failed-slot recovery may the
installer grow into a complete two-slot NixOS updater.

Kexec and native boot remain separate test results because only native boot
exercises LK, AVB, boot image parsing and bootloader DTB/DTBO handling.

### 5. Input and display

Audit `/dev/input/event*` and input mappings before adding a graphical shell.
The DRM node observed under LineageOS is encouraging but does not prove that a
normal Mesa/DRM/KMS stack can scan out or accelerate graphics with the stock
kernel.

Determine whether display requires:

- usable native DRM/KMS;
- a framebuffer-only bring-up;
- proprietary Mali userspace;
- Android Hardware Composer through a compatibility layer.

Only then select Phosh, Plasma Mobile or another compositor.

### 6. LineageOS compatibility container

The target architecture uses the working LineageOS 21 hardware adaptation as
a containerized compatibility shim:

```text
NixOS host
├── systemd, NixOS services and native applications
├── host networking, audio and Wayland integration
└── LineageOS compatibility container
    ├── matching vendor libraries and HALs
    ├── Binder services
    ├── graphics / Hardware Composer
    ├── audio HAL
    ├── radio / IMS
    └── camera HAL
```

Start from the exact LineageOS userspace and `.3001` vendor relationship that
already boots, then reduce the container only when runtime evidence shows
which services are unnecessary. The container shares the NixOS host kernel
and needs deliberately scoped Binder devices, namespaces, mounts, firmware,
device nodes and IPC bridges. Android `init`, SELinux expectations and cgroup
ownership must be reconciled rather than treating the LineageOS filesystem as
an ordinary LXC root.

This requires an explicit audit of the Android and vendor interface versions,
plus a defined host interface for graphics, audio, radio, sensors and camera.
Do not assume that an arbitrary Halium image or a current `libhybris` build
matches the `.3001` vendor stack. Preserve upstream licenses and never commit
proprietary blobs; continue deriving permitted inputs from pinned,
independently verified sources.

### 7. Telephony last

Calls, SMS, mobile data, SIM management, IMS, VoLTE and call audio routing are
the last milestone. MediaTek radio services can require multiple proprietary
Binder services, firmware components and Android framework assumptions.
Successful LineageOS telephony would prove that the vendor stack can perform
the function, not that a NixOS integration exists.

## Safety policy

The NixOS product inherits the repository's conservative hardware policy:

- refuse devices other than model `CPH2399` and product device `OP557AL1`;
- pin and verify every external image input;
- do not commit flashable, stock-derived or proprietary images;
- separate build, audit, read-only preflight and hardware-write commands;
- never treat a successful build or USB transfer as permission to flash;
- never write `preloader`, `lk`, GPT, `vendor_boot`, DTBO, radio,
  calibration, persistent or OPlus partitions during normal bring-up;
- never use an unresolved slot, glob or unwrapped generic `--slot=all` write;
- permit an explicit two-slot NixOS transaction only after the A/B lifecycle
  and exact rollback have their own tests;
- verify the complete stock rollback bundle before an install action;
- document every destructive effect, especially rootfs writes and wipes;
- never relock while any custom boot, AVB or userspace image is installed.

The NixOS installer must be a separate command from
`lineage-userspace`. Shared low-level checks may be factored out only with
tests proving that neither product's allowed write set widened.

## When a second repository becomes appropriate

Do not split merely because the root filesystem is NixOS. Create or use a
second repository only for a real ownership boundary:

1. Kernel source modifications start. Use the vendor and upstream forks
   defined in the kernel source map while this repository owns their pinned
   integration, tests and device-write policy.
2. A cleaned, generally useful `oneplus-karen` Mobile NixOS device definition
   is ready for an upstream pull request. Develop that patch in a fork of
   `mobile-nixos`; keep this repository as the pinned integration and safety
   harness until the change is merged.
3. Reusable MT6893 family support becomes relevant to multiple devices and
   belongs upstream rather than in Karen-specific code.
4. A large Android compatibility project acquires an independent release,
   issue, licensing or maintainer lifecycle.
5. Conventional LineageOS device, kernel and vendor repositories are prepared
   for upstream Android review, as already described in the LineageOS port
   assessment.

Until one of those conditions exists, one Karen integration repository avoids
duplicating the most safety-critical knowledge.

## Licensing and contribution rules

New repository-owned Nix expressions, scripts and documentation should use the
repository's MIT SPDX identifier. Preserve the license, copyright and history
of code copied or adapted from Mobile NixOS, Nixpkgs, the Linux kernel,
LineageOS, Halium or other upstreams.

Android device-tree contributions remain Apache-2.0-compatible and kernel
changes remain GPL-2.0-compatible. Proprietary vendor material must not be
added merely because a Nix derivation can reference it.

AI-assisted commits continue to require the `Assisted-by` trailer specified in
the repository's `AGENTS.md`.

## Current status

This document records an approved repository direction, not a completed
Mobile NixOS port. No NixOS image output, kernel-config result, rootfs target
or hardware write is authorized by this plan. The next safe deliverable is a
build-only kernel and kexec feasibility audit followed by an audited kexec
stage-1 bundle.
