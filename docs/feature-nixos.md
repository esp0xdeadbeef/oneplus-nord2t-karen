<!-- SPDX-License-Identifier: MIT -->

# Mobile NixOS feature plan

Checked against the current UBports, Mobile NixOS, upstream Linux,
postmarketOS and published OnePlus kernel sources on 2026-07-26.

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
├── Lomiri mobile shell on Mir / QtMir
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
rooted LineageOS control system with a kexec-enabled 4.19 kernel
  -> kexec from Magisk
  -> audited NixOS candidate kernel and resolved DTB
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
  configuration.nix
  rootfs.nix
  kexec-bundle.nix
  families/
    mt6893/
      default.nix
      kernel.nix
      firmware.nix
      stage-1.nix
  modules/
    lomiri-mobile.nix
    android-graphics.nix
  devices/
    oneplus-karen/
      default.nix
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

The family/device split follows the proven Mobile NixOS SDM845 pattern. The
MT6893 family owns the kernel package, early firmware closure, USB setup and
boot-family defaults. The Karen device module owns only verified
`CPH2399`-specific facts such as identity, screen geometry, the resolved DTB,
boot-image layout and hardware quirks. This remains useful with only one
MT6893 device because it prevents product facts from leaking into generic
kernel and stage-1 code.

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

1. build-only DTB and effective-kernel-config audits;
2. a kexec-enabled Lineage control kernel on one explicitly selected boot slot
   with an exact restore path;
3. kexec experiments without further persistent partition changes;
4. repeatable native NixOS boot, rollback and slot-failure tests;
5. a Karen-specific A/B installer and updater that may write both slots and
   their matching AVB metadata as one audited transaction.

The rule is therefore “no unwrapped generic `--slot=all`”, not “NixOS may
never use both slots”.

The tested loader also cannot be assumed to support temporary
`fastboot boot`: a complete transfer previously returned to the running slot
with boot reason `lk_crash`. A transfer is not evidence that an image
executed. Any NixOS boot probe must use an explicitly documented, reversible
slot procedure after a complete preflight.

## Kernel feasibility audit

The exact `.3001` stock kernel remains the behavioral oracle and byte-exact
baseline, but its embedded effective configuration proves that it cannot be
the first NixOS or kexec control kernel unchanged. The build-only audit
currently reports `CONFIG_KEXEC`, `CONFIG_DEVTMPFS` and `CONFIG_FHANDLE`
disabled. Before building a flash candidate, continue to audit at least:

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

The published OnePlus MT6893 source and module trees now compile together.
The module tree supplies the previously unresolved `vendor/oplus` layer; four
omitted generated DCT files are restored only after their published DWS
inputs are verified byte-identical. The first required kernel delta remains
tracked as `nixos/families/mt6893/kernel/nixos-control.config`; it enables
classic kexec, devtmpfs, file handles and the missing cgroup controllers
through Kconfig. Build success closes the compile gate, not the hardware-boot
or kexec handoff gates.

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
| [MT6893 community device family](lineage-port.md#active-mt6893-community-device-family) | Maintained Android userspace and source map for related devices | Init, VINTF, SELinux, HAL, blob and generated-DCT archaeology; never Karen partition geometry |
| Pinned MediaTek/OPlus 4.14 donor | Older but more complete BSP evidence | Recover missing implementations and understand hardware contracts |
| Upstream Linux 6.x and adjacent MediaTek SoCs | Current kernel interfaces | Native subsystem design and forward-port destination |

For a 6.x port, use the older source as executable hardware documentation.
Bring up one subsystem at a time with an existing upstream driver where
possible, add MT6893 data and quirks, and port vendor code only where no native
implementation exists. Preserve the old Android userspace UAPI only where the
LineageOS compatibility container needs it; do not build a kernel-wide
emulation of Linux 4.19 internals.

### OnePlus kernel generations

The published OnePlus 5 through 13 kernels form a useful history of how OPlus
moved its common hooks and drivers across Linux API generations:

| Product used for inspection | SoC family | Published branch | Kernel |
| --- | --- | --- | --- |
| [OnePlus 5 / 5T](https://github.com/OnePlusOSS/android_kernel_oneplus_msm8998/tree/oneplus/QC8998_Q_10.0) | Qualcomm MSM8998 | `QC8998_Q_10.0` | 4.4.205 |
| [OnePlus 6 / 6T](https://github.com/OnePlusOSS/android_kernel_oneplus_sdm845/tree/oneplus/SDM845_R_11.0) | Qualcomm SDM845 | `SDM845_R_11.0` | 4.9.227 |
| [OnePlus 7](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8150/tree/oneplus/sm8150_s_12.1_op7pro) | Qualcomm SM8150 | `sm8150_s_12.1_op7pro` | 4.14.180 |
| [OnePlus 8T](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250/tree/846e71f228ad605c75b53064c4c165a1361a0bfe) | Qualcomm SM8250 | `sm8250_u_14.0.0_op8t` | 4.19.157 |
| [OnePlus 9](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8350/tree/9e38a9fabb4de096bf386b7be988b7f7c5e4c58e) | Qualcomm SM8350 | `sm8350_u_14.0.0_oneplus9` | 5.4.254 |
| [OnePlus 10 Pro](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8450/tree/449760504b3a75728eb60479f5b34dc51cb263ce) | Qualcomm SM8450 | `sm8450_v_15.0.0_oneplus_10_pro` | 5.10.226 |
| [OnePlus 11](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8550/tree/c462ef8ffab7a58e035ee04705b16cdfced494b1) | Qualcomm SM8550 | `sm8550_v_15.0.0_oneplus11` | 5.15.167 |
| [OnePlus 12](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8650/tree/e39bf7032e38c547d588372a11a5dd55eb714860) | Qualcomm SM8650 | `sm8650_v_15.0.0_oneplus12` | 6.1.118 |
| [OnePlus 13](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8750/tree/d09a875fd283664a4ad3a8722fb608356985dab1) | Qualcomm SM8750 | `sm8750_v_15.0.0_oneplus_13` | 6.6.66 |

These are not a sequence of patches that can be replayed to turn Karen into a
6.x device. Most of the SoC integration is Qualcomm-specific. They are useful
for finding the same OPlus feature before and after a kernel API change, for
seeing when a private hook was removed, and for finding generic replacements
for OPlus charging, touch, fingerprint, network, security and performance
code.

The OnePlus 8T snapshot is especially valuable for the first 4.19 source-build
experiment. The published Karen kernel contains 60 symlink entries into 53
unique `vendor/oplus` targets that are absent from its repository. A tree-only
audit found the following exact or directory-prefix coverage:

| Pinned OPlus module source | Kernel generation | Karen link entries present |
| --- | --- | ---: |
| [OnePlus 8T Android 14](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250/tree/0a301570ef70f6f9bfe1840451c9d41f5ddce6b8/vendor/oplus) | 4.19 | 58 / 60 |
| [OnePlus 9 Android 14](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8350/tree/d95833d6520887112ffed6537bfbef5e28650ca1/vendor/oplus) | 5.4 | 57 / 60 |
| OnePlus 10 Pro through 13 Android 15 snapshots | 5.10 through 6.6 | 17 / 60 each |

The two OnePlus 8T misses are both the `oplus_performance/klockopt` category.
That makes the 8T publication a strong source-level donor for reconstructing
the missing 4.19 OPlus layer, not proof that it is the unpublished Karen
release source. Path presence says nothing about Kconfig selections, board
data, symbol versions, generated headers, downstream changes or the hardware
behind a driver.

A bounded reconstruction experiment may:

1. pin both OnePlus 8T commits shown above;
2. materialize only the exact directories requested by Karen's symlinks in
   the expected `vendor/oplus` position;
3. make no code edits for the first compile attempt;
4. record every missing symbol, header and configuration dependency;
5. resolve `klockopt` separately and disable it only if the effective stock
   configuration and runtime requirements prove it optional;
6. compare failures with later OPlus revisions instead of merging whole
   device trees.

Any result remains a reconstructed source tree. It must not be labelled an
exact OnePlus Nord 2T 5G publication, and a successful compile does not authorize
booting or flashing it.

### MediaTek forward-port bridges

The newer OnePlus MediaTek publications are more relevant to native 6.x work
than the Qualcomm OnePlus 9 through 13 kernels:

| Product used for inspection | SoC | Pinned or named branch | Kernel | Porting role |
| --- | --- | --- | --- | --- |
| [Nord CE 2](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6877/tree/3c1e3d432d0c35afa7fded974b50fa6617219e0f) | MT6877 | `mt6877_t_13.0.0_nord_ce2` | 4.19.191 | Adjacent 4.19 MediaTek/OPlus baseline |
| [Nord 2T](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893/tree/a5cdca1a88dc328a44dee724193830254fc551da) | MT6893 | `mt6893_14_14.0.0_nord_2t_5g` | 4.19.191 | Exact device source baseline |
| [OnePlus 10R](https://github.com/OnePlusOSS/android_kernel_5.10_oneplus_mt6895/tree/f3e95e79e03d984d1e16ad31bdf66d62ce80f7be) | MT6895 | `mt6895_v_15.0.0_oneplus_10r` | 5.10.209 | Closest intermediate SoC/API bridge |
| [Nord 3](https://github.com/OnePlusOSS/android_kernel_5.10_oneplus_mt6983/tree/f5b6dd4fc9c3eedb2db321b60c906af6aeea0c0f) | MT6983 | `mt6983_b_16.0.0_nord_3` | 5.10.236 | Newer 5.10 MediaTek implementation |
| [Nord CE 5](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6897/tree/e17c1ca9ddf6122d8c6ec62c958a257365d6260e) | MT6897 | `mt6897_b_16.0.0_nord_ce5` | 6.1.134 | Modern 6.1 MediaTek/OPlus reference |
| [Nord N30 SE](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6833/tree/867955635f4ed678c985a4b3b5fac29feece9cae) | MT6833 | `mt6833_v_15.0.0_nord_n30_se_5g` | 6.6.30 | Modern 6.6 MediaTek/OPlus reference |

Their separate module repositories retain substantial structural overlap with
the published Karen module tree. A filename-level inventory found about 3,400
to 3,600 shared basenames between Karen's 9,812 module files and each selected
5.10, 6.1 or 6.6 tree. This is only a discovery metric, but it exposes later
implementations of MediaTek DRM/DDP, CMDQ, UFS, DVFS, camera CCU, connectivity,
power and OPlus integration code:

- [MT6895 Android 15 modules](https://github.com/OnePlusOSS/android_vendor_mediatek_kernel_modules_mt6895/tree/189765887074ef7d1135e900d34932251fc3af58);
- [MT6983 Android 16 modules](https://github.com/OnePlusOSS/android_kernel_modules_oneplus_mt6983/tree/f7ec362eedc982b45828857448521bfd451d4f52);
- [MT6897 Linux 6.1 modules and device trees](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_mt6897/tree/3e843a44bcf2738d421e6a08ce753ee71893be47);
- [MT6833 Linux 6.6 modules](https://github.com/OnePlusOSS/android_kernel_modules_oneplus_mt6833/tree/9018c48d2e0ea07b6cbdac909a3225f2a5070ec0).

The same path-only audit found 21 of Karen's 60 missing OPlus link entries in
the MT6895 tree, 20 in MT6833 and 58 in MT6897. The MT6897 misses are the
legacy `vendor/oplus/kernel/system` directory and its include directory; the
union of MT6897 and MT6895 contains all 60 path categories. This demonstrates
that later public implementations exist for every missing category. It does
not establish that their ABIs or behavior match Karen.

Use these sources as a per-subsystem migration ladder:

```text
Karen stock behavior and resolved DTB
  -> Karen / OnePlus 8T 4.19 implementation
  -> MT6895 or MT6983 5.10 implementation
  -> MT6897 6.1 and MT6833 6.6 implementation
  -> current upstream Linux subsystem
```

For each subsystem, identify the hardware contract in the old source, compare
the later MediaTek conversions, and then implement the smallest upstream-style
MT6893 driver or data addition. Do not merge an entire later SoC BSP. In
particular, newer SMMU, clock, power-domain and GKI module layouts are useful
API examples but are not substitutes for MT6893's old M4U relationships,
register maps or firmware contracts.

### OnePlus 6 as a full-Linux and NixOS reference

The OnePlus 6 is the strongest available OnePlus architecture donor, but not a
Karen driver donor. At inspected Mobile NixOS commit
[`2c132754323fc1915e8d21dcfc0ef68ab084c6fb`](https://github.com/mobile-nixos/mobile-nixos/tree/2c132754323fc1915e8d21dcfc0ef68ab084c6fb):

- the
  [`oneplus-enchilada` device module](https://github.com/mobile-nixos/mobile-nixos/blob/2c132754323fc1915e8d21dcfc0ef68ab084c6fb/devices/oneplus-enchilada/default.nix)
  is only 25 lines and imports a shared `sdm845-mainline` family;
- the
  [family module](https://github.com/mobile-nixos/mobile-nixos/blob/2c132754323fc1915e8d21dcfc0ef68ab084c6fb/devices/families/sdm845-mainline/default.nix)
  owns the kernel, stage-1 firmware closure, Android boot layout, appended DTB,
  USB gadget functions and SoC-level quirks;
- device firmware is a separate, pinned, explicitly unfree derivation;
- large modem firmware is deliberately omitted from stage 1.

The exact Mobile NixOS kernel pin is not the current state of the OnePlus 6
port. Its family module still selects the SDM845 project's 6.4 release, while
postmarketOS commit
[`88e3ba5b6f9456761b078d9baa0081cb640ec5ba`](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/tree/88e3ba5b6f9456761b078d9baa0081cb640ec5ba/device/community)
packages `sdm845-7.1-rc1-r0` and current userspace integration for firmware,
audio, remote processors, the modem, A/B boot control and voice calls. Reuse
the Mobile NixOS module shape, but check the active mainline and postmarketOS
ports rather than copying its old kernel pin.

The current upstream device description is also instructive:

- the
  [large SDM845 OnePlus common DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sdm845-oneplus-common.dtsi)
  describes shared hardware;
- the
  [Enchilada DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sdm845-oneplus-enchilada.dts)
  is a small model delta;
- generic upstream drivers handle buttons, the alert slider, touchscreen,
  fuel gauge, NFC, PMIC charging, LEDs, haptics, audio and the panel.

The initial
[OnePlus 6 mainline device-tree commit](https://github.com/torvalds/linux/commit/288ef8a42612)
landed in 2021. Display, Wi-Fi, audio, battery, charger, sensors, NFC, alert
slider and other functions were then added or corrected in separate changes.
“Full Linux” was therefore achieved through generic subsystem drivers,
accurate device-tree data, firmware packaging and small userspace services,
not by translating all 4.9 kernel APIs behind one compatibility shim.

The reusable OnePlus 6 constructs are:

- a small device module on top of a SoC-family module;
- separate, pinned firmware packaging and a minimal stage-1 firmware closure;
- one common SoC kernel with a model-specific DTB;
- declarative USB gadget networking for early access;
- ramoops/pstore and, if the bootloader exposes one, a simple framebuffer for
  early diagnostics;
- gradual replacement of vendor functions by standard kernel subsystems;
- userspace daemons for remaining firmware or modem protocols.

Do not copy its Qualcomm boot offsets, 4 KiB page size, DTB name, firmware
paths, remoteproc/QRTR/QMI/q6voice stack or DTBO-erasure instructions. Karen
must continue to use its audited 2 KiB, header-v2 image and MediaTek-specific
hardware contract. A bootloader-provided framebuffer, ramoops region or
generic input binding is useful only after it is confirmed in Karen's resolved
live device tree.

The OnePlus 6 port does not run LineageOS as a hardware container; it has
native mainline support. That is still directly relevant to the intended
Karen architecture: keep NixOS in control and shrink the LineageOS
compatibility island subsystem by subsystem whenever a native driver and
userspace service become viable. The container is a pragmatic bridge for the
remaining vendor HALs, not a permanent requirement for hardware that native
Linux can already own.

At the inspected upstream Linux revision, OnePlus device trees exist for the
OnePlus 3/3T, 5/5T, 6/6T and the Nord N100. There is no complete upstream
MT6893 device tree. The older mainline OnePlus ports demonstrate the method,
while the newer official Android kernels primarily supply vendor API history.

### Ranked donor use

Use sources in this order and preserve the distinction in commit messages:

1. `.3001` runtime observations, stock images and the resolved live DTB are
   Karen behavior ground truth.
2. The pinned OnePlus MT6893 4.19 kernel and module trees define the closest
   published source baseline.
3. The pinned OnePlus 8T 4.19 OPlus tree is the first donor when a genuinely
   missing or incomplete Karen OPlus implementation needs API history.
4. The MT6895 and MT6983 5.10 trees explain the intermediate MediaTek API
   conversion.
5. The MT6897 6.1 and MT6833 6.6 trees show modern MediaTek and OPlus module
   structure.
6. Upstream Linux defines the native driver target.
7. The OnePlus 6 Mobile NixOS and postmarketOS ports define integration
   structure and bring-up practice, not MediaTek implementation.
8. Other OnePlus 5 through 13 Qualcomm trees are OPlus history references
   only.

### Fork decision

Create a fork of
[`OnePlusOSS/android_kernel_oneplus_mt6893`](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893)
when source-kernel work starts. Base its Karen branch on
`oneplus/mt6893_14_14.0.0_nord_2t_5g` at
`a5cdca1a88dc328a44dee724193830254fc551da`. This is the primary vendor-kernel
fork for:

- maintaining the combined official kernel/module integration and replacing
  only demonstrably incomplete vendor components;
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

Do not create development forks of every OnePlus donor now. Keep the OnePlus
8T and later MediaTek commits above as pinned, read-only remotes or Nix inputs.
Fork one only after there is a reviewed change that genuinely belongs against
that upstream. The actionable first fork remains the exact OnePlus MT6893
repository; the integration repository remains this repository.

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
[`k6893v1_64_k419_ab_defconfig`](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893/blob/a5cdca1a88dc328a44dee724193830254fc551da/arch/arm64/configs/k6893v1_64_k419_ab_defconfig)
does not list `CONFIG_KEXEC`, `CONFIG_KEXEC_FILE` or `CONFIG_CRASH_DUMP`.
This is the correct OnePlus virtual-A/B baseline for Karen: unlike the generic
MT6893 defconfig, it selects the 21127/21881-era DTBO and display feature set.
Using the generic baseline leaves its OPlus display and battery callers paired
with the wrong guarded implementations and fails at the final kernel link.
OnePlus's ARM64
[Kconfig](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893/blob/a5cdca1a88dc328a44dee724193830254fc551da/arch/arm64/Kconfig#L930)
does contain the classic `kexec_load` implementation, but it is an optional
kernel setting.

The initial scaffold has now extracted `IKCONFIG` from the decompressed
`.3001` `Image.gz` and confirmed `CONFIG_KEXEC` is disabled and
`CONFIG_KEXEC_FILE` is absent. This closes the first hard gate negatively:
Magisk root and the module cannot compensate because the syscall
implementation was compiled out. A source-built, kexec-enabled 4.19 Lineage
control kernel is required before `evdenis/kexec` can be tested.

### Why userland cannot replace the missing syscall

Android root changes credentials and capabilities, but the process still runs
at ARM64 exception level EL0. The kernel runs at EL1. That boundary is enforced
by the CPU, page tables and syscall dispatcher; it is not an Android property
that Magisk can mask.

On the exact stock kernel, a userspace loader encounters two independent
negative gates:

```text
kexec_load(kernel, initrd, dtb, command line) -> ENOSYS
reboot(LINUX_REBOOT_CMD_KEXEC)                -> EINVAL
```

The first operation has no compiled syscall implementation. The second has no
previously loaded `kimage` to execute. `uid=0` and `CAP_SYS_BOOT` are required
when kexec exists, but cannot create absent kernel code.

The same boundary excludes several apparent shortcuts:

| Candidate shortcut | Boundary |
| --- | --- |
| Magisk `kexec` module | Installs `kexec-tools` in userspace only |
| Recovery `init.rc` service | Still invokes the running kernel's absent syscall |
| eBPF | Runs verifier-constrained programs; it cannot install an arbitrary ARM64 reboot trampoline |
| `ptrace` or namespaces | Affects user processes, not the EL0/EL1 boundary |
| Direct PSCI/SMC from an application | EL0 cannot issue an unrestricted platform firmware transition |
| Flip `IKCONFIG` or a boot property | Changes reported configuration at most; the machine code is absent |
| Loadable “kexec module” | Must recreate the architecture loader, CPU stop, cache/MMU and jump path and still pass module loading/signature gates |
| Arbitrary kernel-memory write | Is a kernel exploit, not a userland kexec implementation |

A vendor device node that accidentally permits arbitrary kernel execution
would be a vulnerability. Depending on such a primitive would be harder to
audit and more likely to corrupt unrelated memory than enabling OnePlus's
already present ARM64 kexec implementation in a reviewed source build.
`kexec-hardboot` likewise requires kernel and usually bootloader-specific
support; it is not a userspace fallback.

The project therefore permits one minimal persistent prerequisite: a
kexec-enabled control kernel on inactive `boot_b`. It does not permit another
experimental control kernel write to the known-good active `boot_a`.

### Recovery-B RAM trampoline

The control system does not need to boot the complete Android vendor stack.
It can use a self-contained Lineage Recovery ramdisk on B:

```text
LK
  -> boot_b: reviewed 4.19 control kernel + recovery ramdisk
       -> authenticated recovery ADB
       -> select known-good A for the next cold boot
       -> load kernel + initrd + resolved DTB into RAM
       -> kexec
            -> NixOS stage 1 in RAM
                 -> USB-only callback

Any cold reset
  -> LK
       -> boot_a: known-good LineageOS
```

This avoids loading the full set of stock Android vendor modules in the
control environment. Consequently, the full Android module-ABI gate and the
smaller recovery-kernel gate must be reported separately: a recovery canary
may prove CPU, memory, USB and kexec without authorizing that kernel as a
daily Android boot image.

The boot-control guard must run before loading a candidate. Its intended calls
from the already booted B recovery are:

```sh
bootctl get-current-slot
# required: 1

bootctl is-slot-bootable 0
# required: true

bootctl is-slot-marked-successful 0
# required: true

bootctl is-slot-marked-successful 1
# required: false; never mark the control slot successful

bootctl set-active-boot-slot 0
bootctl get-active-boot-slot
# required: 0

sync
```

Those commands describe the AOSP interface, not yet proven Karen recovery
behavior. First run them with the already working stock-kernel Lineage
Recovery on B, reboot without kexec and prove that A starts. Also prove the
independent B retry/fallback behavior. If recovery lacks the applicable boot
HAL, if either query is unavailable or if the next cold boot is not A, the
automated kexec path remains blocked.

Do not start kexec unconditionally from `early-init`. An unconditional action
would turn one bad RAM candidate into an automatic warm-reboot loop. The
recovery should instead:

1. run the boot and slot attestations;
2. select A for the next cold boot and verify that selection;
3. start authenticated ADB;
4. wait for a host-provided, hash-manifested one-run bundle in tmpfs;
5. load the candidate without executing it;
6. permit a separate explicit execute action only after the load audit passes;
7. reboot to A after a timeout or any failed gate.

The host-to-recovery staging shape is:

```sh
adb wait-for-recovery
adb push ./karen-kexec-bundle /tmp/karen-kexec
adb shell 'cd /tmp/karen-kexec && sha256sum -c SHA256SUMS'
```

`wait-for-recovery` denotes a wrapper requirement, not a portable adb
subcommand guaranteed by every platform-tools version. The final helper must
attest exactly one recovery device rather than relying on an ambiguous
`adb wait-for-device`.

After boot-control and bundle checks, the intended classic ARM64 userspace
calls are:

```sh
kexec -l /tmp/karen-kexec/Image \
  --initrd=/tmp/karen-kexec/initrd.gz \
  --dtb=/tmp/karen-kexec/live.dtb \
  --command-line='rdinit=/init karen.nixos.callback=1'

# Separate non-destructive gate:
kexec -u

# A later run may load the same audited bundle again, then explicitly jump:
kexec -e
```

The exact CLI and accepted kernel format must be checked against the pinned
ARM64 `kexec-tools` build before these become repository entrypoints. Under
the interface, `kexec -l` invokes `kexec_load`; `kexec -e` requests
`LINUX_REBOOT_CMD_KEXEC`. Linux then performs the generic reboot preparation,
device and syscore shutdown, stops secondary CPUs and enters ARM64
`machine_kexec`. There is no `mtkclient`, Download Agent, preloader or LK call
in that warm transition. MediaTek-specific risk is in whether its running
drivers quiesce DMA, interrupts and coprocessors correctly before the generic
ARM64 jump.

The `live.dtb` input must be the reviewed bootloader-resolved tree captured
privately from the running control kernel, not the unresolved base DTB copied
from `boot.img`. It can contain device-specific values and must remain outside
Git, the Nix store and the remote build host.

The first target remains the existing all-in-RAM stage-1 initramfs. It must
not mount, repair or write UFS, change GPT, mark B successful or store a NixOS
root filesystem. Its only expected success signal is the USB callback. This
does not make the test risk-free, but it confines persistent phone changes to
the separately recoverable `boot_b` control image and boot-control selection.

### Kexec gates

Establish each gate independently:

1. Preserve the effective `.3001` config audit and its hash as the negative
   stock baseline.
2. Reproduce the successful pinned 4.19 build with
   `nixos-control.config` and its reviewed source/DCT patches.
3. Package the control kernel with the exact reviewed DTB/DTBO relationship
   and install it to one recoverable boot slot with its matching AVB metadata.
4. Confirm `CONFIG_KEXEC=y` in that running kernel and distinguish a syscall,
   SELinux or device-shutdown failure.
5. Pin the exact GPL-2.0 `evdenis/kexec` source or release and verify its hash;
   do not resolve `latest` during a test.
6. Verify that the ARM64 tool accepts the intended kernel format, initrd,
   command line and DTB.
7. Load and unload a harmless candidate without executing it.
8. Execute an initrd-only diagnostic candidate with no writable rootfs.
9. Repeat cold-return recovery to the installed LineageOS control system.
10. Add the NixOS rootfs and systemd only after the diagnostic initrd is
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

The first ARM64 diagnostic initramfs is exported without handling a Nix store
path:

```sh
nix run .#nixos-kexec-initramfs -- ./result-nixos-kexec-initramfs
```

It contains only a static AArch64 BusyBox stage 1. The callback remains
disabled unless the reviewed second-kernel command line contains
`karen.nixos.callback=1`; when enabled, it creates a USB-only RNDIS link with
the phone at `192.168.97.2/30` and calls `192.168.97.1:9001`. No Wi-Fi
credential, private key or device-unique identifier is embedded. The fixed
locally administered USB MAC addresses are protocol constants, not secrets.

The ABI-preserving Android control kernel deliberately retains stock's
`CONFIG_DEVTMPFS=n`. Stage 1 therefore mounts an ephemeral tmpfs at `/dev` and
creates only the generic device nodes it needs at runtime; it does not assume
devtmpfs or package persistent device nodes into the archive. The exported
manifest records this boundary. Building and hashing this initramfs proves
only its architecture and contents—the callback remains a hardware gate until
the control kernel, live resolved FDT and kexec transition have all succeeded.

Do not blindly pass the base DTB extracted from `boot.img`. The OnePlus
bootloader normally applies DTBO and may fix up the tree before the first
kernel starts. Compare the boot DTB, stock DTBO and live flattened device tree
and determine which fully resolved DTB the second kernel requires.

The first executable bundle may keep the complete diagnostic userspace in a
large initrd. Kexec loads that initrd from Android RAM and is not constrained
by the 64 MiB boot partition, so this can prove a minimal NixOS/systemd closure
without first assigning a persistent rootfs partition. Memory use and the
exact closure size must still be audited.

Each kexec jump leaves boot, vbmeta and logical partitions untouched. Reaching
that state now has a separate prerequisite write: installing the
kexec-enabled Lineage control boot pair. Kexec is not risk-free: a
device-driver shutdown failure can still hang the phone, and the warm hardware
state differs from a bootloader cold boot. A successful result is therefore
necessary bring-up evidence, not proof that the final native boot image works.

### Kexec test matrix

Do not reduce kexec validation to one successful jump. Record the input hashes,
control-system state and observable result for at least:

- tool execution and syscall detection without a loaded candidate;
- load followed by unload, with no jump;
- the exact stock kernel plus a tiny diagnostic initrd;
- the kexec-enabled 4.19 candidate plus the Mobile NixOS stage-1 initrd;
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
2. Preserve the extracted effective stock-kernel audit.
3. Reconstruct and build the kexec-enabled 4.19 control kernel.
4. Generate a Mobile NixOS stage-1 initrd without a GUI.
5. Build and audit a kexec bundle without installing it.
6. Independently assemble a Karen header-v2 boot image for the later native
   boot phase.
7. Verify size, header, offsets, kernel, DTB, ramdisk and AVB metadata.
8. Produce no flash script until the image audit and exact restore set exist.

### 1. Kexec load and unload

Install the audited kexec-enabled 4.19 control boot pair to one selected slot
only after its exact stock restore pair passes preflight. Boot rooted LineageOS
with that kernel, then prove tool installation, syscall availability and
SELinux behavior. Loading and unloading the diagnostic candidate makes no
additional persistent partition write.

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

Lomiri is the selected mobile UX, but it must not be activated until one of
those graphics paths has been demonstrated independently.

#### Lomiri without an Ubuntu target

Use [Lomiri](https://lomiri.com/), formerly Unity8, as a native NixOS desktop
session. Do not build an Ubuntu root filesystem merely to obtain the Ubuntu
Touch interface. Lomiri is not only a window manager: it includes the shell,
session integration and Qt/QML components and runs on Mir through QtMir.

The Nixpkgs revision currently pinned by this repository already provides
Lomiri, Mir, QtMir, the Lomiri session, settings, indicators and applications
for `aarch64-linux`. Its full
[NixOS Lomiri module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktop-managers/lomiri.nix)
can provide a desktop reference configuration:

```nix
{
  services.desktopManager.lomiri.enable = true;
  services.displayManager.defaultSession = "lomiri";
}
```

Do not enable that full module unchanged during early phone bring-up. It also
selects desktop-oriented integration such as LightDM, Xwayland,
NetworkManager, indicators, applications and telephony components. First
create a smaller `nixos/modules/lomiri-mobile.nix` boundary that can start
only Mir, QtMir and the shell against an already proven display and input
stack. Add the remaining session services declaratively after the minimal
shell is observable.

The intended rendering paths are:

```text
NixOS host
└── Lomiri shell and session
    └── QtMir / Mir
        ├── native DRM/KMS plus Mesa
        └── libhybris / mir-android2-platform
            └── Android HWC and Mali services in the Lineage container
```

Prefer native DRM/KMS when the hardware and kernel expose a usable scanout and
acceleration path. The likely initial Karen route is instead the
container-backed path because the working display stack currently depends on
Android vendor components. UBports maintains
[Hybris support components](https://gitlab.com/ubports/development/core/hybris-support),
including
[`mir-android2-platform`](https://gitlab.com/ubports/development/core/hybris-support/mir-android2-platform),
specifically to let Mir use Android graphics drivers through libhybris.
Package and pin those sources as Nix derivations rather than importing Ubuntu
packages or making Ubuntu a build target.

Bring up Lomiri in this order:

1. prove that Mir can open the selected native or Android-backed display;
2. prove touch and screen geometry without a complete desktop session;
3. start the minimal Lomiri shell;
4. add the on-screen keyboard, settings and indicators;
5. add applications and content integration;
6. connect telephony UI only after the separate radio milestone succeeds.

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
Mobile NixOS port. The initial build-only scaffold under `nixos/` now records
the MT6893 family, Karen identity and verified boot layout. Its first
derivation extracts the exact `.3001` DTB, decompiles it to canonical DTS,
applies an ordered source patchset, recompiles it and records a semantic diff
and hash manifest.

The boot payload named `dtb` is an Android DT table v0 containing one FDT
entry, not a raw FDT at offset zero. The scaffold validates and rebuilds that
wrapper with a format-aware tool rather than baking its currently observed
entry offset into a byte patch.

The patchset deliberately starts empty. A real device-tree change requires a
comparison of the base DTB, stock DTBO and live bootloader-resolved tree.
Direct fixed-offset changes to DTB or compressed kernel images are not a
forward-port mechanism: structured offsets, phandles, linked machine code,
kernel-internal APIs and AVB authentication all change independently. Firmware
compatibility shims remain possible, but must be implemented as source drivers
against current kernel interfaces.

The effective stock-kernel audit is now implemented and confirms 41 inspected
options built in, seven disabled and five absent or unresolved. RNDIS configfs,
networking, ext4, F2FS, device mapper, overlayfs, Binder, binderfs and pstore
are present. Classic kexec, devtmpfs and file handles are disabled; the
unmodified stock kernel therefore cannot satisfy the intended first boot.

The 4.19 build-only control-kernel gate is now successful. Its effective
configuration contains classic kexec, devtmpfs, file handles and the requested
cgroup controllers, and its DTB remains byte-identical to stock. The generated
diagnostic recovery ramdisk deliberately has insecure ADB and is neither
Magisk-rooted nor a flash candidate.

No NixOS boot image, rootfs target or hardware write is authorized by this
scaffold. The next safe deliverable is a secure key-bound Lineage bootpair
that combines the successful source kernel with matching AVB and the
root-full control profile, followed by a hardware boot and kexec load/unload
test. The exact firmware, DTB and native-driver classification is maintained
in the [NixOS blocker matrix](nixos-blockers.md).
