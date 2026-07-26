<!-- SPDX-License-Identifier: MIT -->

# NixOS firmware, DTB and driver blockers

Last audited: 2026-07-26.

## Conclusion

There is no known missing downloadable, non-unique firmware blob for the
audited `CPH2399_14.0.0.3001(EX01)` baseline. The exact public OTA is pinned
by `flake.lock`, and `firmware/partitions-3001.json` covers its boot firmware,
coprocessor images, kernel/DTBO/AVB images and Android filesystems. Exact
runtime firmware and proprietary HALs are also present in its verified
`vendor` and `odm` images.

That does not make a native current-kernel port complete:

- the vendor 4.19 control kernel now compiles, but has not booted on Karen;
- the static stock DTB plus Karen DTBO can be reconstructed, but the live
  bootloader-resolved FDT still needs a private capture and structural diff;
- upstream Linux has only minimal MT6893 support and no MT6893 SoC DTS;
- many usable phone functions still depend on bionic-linked proprietary
  Android HALs rather than native glibc interfaces;
- device-unique radio and calibration state cannot be downloaded by design
  and must remain in its existing partitions.

The shortest path to a first headless NixOS boot is therefore the source-built
OnePlus 4.19 kernel through kexec. A fully native current upstream kernel is a
separate and much larger driver port. A DTB is necessary for both paths, but
cannot replace missing kernel drivers or firmware protocols.

## Bootstrap versus final native boot

The current Lineage/Magisk boot image is a bootstrap, not the final NixOS
product:

```text
current:
  LK -> Android boot.img (4.19 + Lineage ramdisk + DTB)
     -> Lineage/Magisk -> kexec -> NixOS experiment

final native:
  LK -> Karen Android-header-v2 boot.img
     (tested NixOS kernel + Mobile NixOS stage-1 initrd + matching DTB)
     -> NixOS rootfs -> systemd
```

In the final native path, NixOS replaces `boot_a`; Magisk and LineageOS are no
longer in the host boot path. `boot.img` is still only a boot wrapper, not the
complete operating system. The NixOS root filesystem needs a separately
audited UFS placement.

The eventual reproducible port therefore includes more than disko, one DTB
and `configuration.nix`:

- kernel source/configuration and reviewable subsystem patches;
- MT6893 SoC DTSI, Karen board DTS and the compiled DTB;
- Mobile NixOS stage 1 and the normal NixOS configuration;
- Karen header-v2 boot-image and AVB assembly;
- pinned firmware extraction and a minimal early firmware closure;
- storage, installation, rollback and update logic;
- later, the Android HAL compatibility boundary required for full phone
  functionality.

Disko may describe the selected rootfs layout, but must not infer that a
normal PC partitioning workflow can recreate Android `super`, its dynamic
partitions or Karen's fixed boot-chain layout. Preloader, LK, TEE,
coprocessor firmware and device-unique calibration partitions remain in place.

## Audited public sources

The conclusions above use exact revisions rather than moving branches:

- the official
  [OnePlus MT6893 4.19 kernel](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893/tree/a5cdca1a88dc328a44dee724193830254fc551da)
  at `a5cdca1a88dc328a44dee724193830254fc551da`;
- the matching
  [OnePlus MediaTek/OPlus modules](https://github.com/OnePlusOSS/android_vendor_mediatek_kernel_modules_mt6893/tree/a198b1d0e4ca41cf48d62793e65a9484ad833312)
  at `a198b1d0e4ca41cf48d62793e65a9484ad833312`;
- the active
  [MT6893 community device family](https://github.com/mt6893-development/android_device_oplus_op6893/tree/3e5d76cb40b327b563784316b2eb1c96363b5c5d)
  at `3e5d76cb40b327b563784316b2eb1c96363b5c5d`;
- its older
  [proprietary vendor map](https://github.com/mt6893-development/proprietary_vendor_oplus_op6893/tree/8fe449a1b6aad2b3c6db675c2131b590a7584cf3)
  at `8fe449a1b6aad2b3c6db675c2131b590a7584cf3`;
- upstream Linux at
  [`3dab139d4795f688e4f243e40c7474df00d329d9`](https://github.com/torvalds/linux/tree/3dab139d4795f688e4f243e40c7474df00d329d9).

The [UBports porting introduction](https://docs.ubports.com/en/latest/porting/introduction/Intro.html)
is the model used for separating the Linux rootfs, device adaptation and
Android-version-specific proprietary material.

## What “blob” means here

Four different classes are often called blobs. They have different safety
and licensing rules:

| Class | Examples | Availability | Repository policy |
| --- | --- | --- | --- |
| Boot and coprocessor firmware | `preloader_raw`, `lk`, `tee`, `gz`, `md1img`, `scp`, `sspm`, `mcupm`, camera VPU and audio DSP | Exact `.3001` bytes are online and pinned | Verify and preserve; do not modify for the first NixOS boot |
| Runtime device firmware | Wi-Fi/BT MCU, camera CCU, GPU workaround, touch, charging and audio tuning files | Exact files are in verified `.3001` `vendor`/`odm` | Package as an explicitly unfree derivation when a driver needs them |
| Android HALs and services | graphics, camera, audio, radio/IMS, GNSS, sensors, biometrics, NFC and power | Exact binaries are in verified `.3001` `vendor`/`odm` | Keep out of Git; use only through a reviewed Android compatibility boundary |
| Device-unique state | `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`, `protect*`, IMEI/MAC and calibration | Deliberately not downloadable or interchangeable | Never extract for publication or send to a build host; access only in place |

The last class is not an online-source blocker. It belongs to the physical
phone and survives the NixOS port in its existing partitions. A first
headless boot must not need to read it. Later radio, Wi-Fi, camera and sensor
validation may require vendor services or native drivers to consume selected
calibration through their existing kernel interfaces.

## Exact `.3001` inventory

The partition manifest includes the non-unique firmware chain:

```text
preloader_raw lk tee gz dpm spmfw pi_img
md1img scp sspm mcupm audio_dsp cam_vpu1 cam_vpu2 cam_vpu3
boot dtbo vbmeta vbmeta_system vbmeta_vendor
system system_ext product vendor odm
```

The verified filesystem inventory contains 82 files below
`vendor/firmware` and 1,913 files below `odm/firmware`. Examples tied to
specific hardware are:

- `WIFI_RAM_CODE_soc3_0_1a_1.bin` and the `soc3_0_ram_bt_*` files;
- camera `lib3a.ccu`;
- Mali `valhall-1691526.wa`;
- Karen project `21881` FT3518 Samsung touch firmware;
- 22 fast-charge files, including the `21881` VOOC generation;
- TFA98xx and AW88264 speaker/audio tuning;
- UFS controller updater images.

The large `odm/firmware` count includes 1,380 root-level haptic waveforms and
459 TFA98xx tuning files. Those are not all needed in stage 1. The eventual
firmware derivation must start with only what the built-in storage and USB
drivers request, then add closures per enabled subsystem.

The community vendor repository has 1,505 file objects at the pinned
revision. Of those paths, 1,388 also exist in current `.3001` `vendor` or
`odm`. This makes it a useful Android 14-era file and interface map, but not
an exact Karen blob source: it lacks several current `.3001` names, including
the Wi-Fi/BT, camera CCU, GPU workaround, `21881` touch and `21881` charging
files above. Those exact bytes are nevertheless available in the pinned
official OTA.

## Blocker matrix

“First boot” means a headless NixOS stage 1 reaching systemd and authenticated
USB networking. “Full phone” means practical graphics, audio, radio, camera
and sensor parity.

| Area | Exact bytes online | Source/native status | First-boot blocker | Full-phone blocker |
| --- | --- | --- | --- | --- |
| Boot firmware and AVB | Yes, pinned `.3001` | Keep the known-good chain | No, when left untouched | No |
| UFS and basic block access | Firmware is available | Vendor 4.19 driver exists; current upstream MT6893 integration is incomplete | Must be proved in the source control kernel and stage 1 | No after proof |
| USB gadget | No private blob identified | Vendor 4.19 support exists; configfs/RNDIS is enabled | Needs authenticated recovery path and runtime test | No after proof |
| Wi-Fi/Bluetooth/GNSS | Yes | Vendor modules, firmware and Android services exist; native current-kernel path incomplete | No for USB-only first boot | Yes |
| Display/GPU/touch | Yes where firmware is used | Vendor display/touch stack exists; no complete upstream Karen stack | No for headless first boot | Yes |
| Audio/camera | Yes | Proprietary HALs, tuning and vendor kernel interfaces dominate | No for headless first boot | Yes |
| Modem/RIL/IMS | Modem image is pinned | Android RIL/IMS and vendor kernel interfaces dominate | No in airplane-mode first boot | Yes |
| Power, charging, thermal and suspend | Firmware/tuning available | Vendor drivers and services exist; native policy is incomplete | Basic safe power behavior must be tested | Yes |
| Fingerprint/NFC/keymaster/TEE | Relevant public firmware/services are present | Mostly proprietary Android interfaces | No | Yes |
| Device-unique calibration | No, by design | Must be consumed in place | No | Required for correct hardware behavior |

The Android binaries are a compatibility blocker, not a download blocker.
They are bionic-linked and cannot simply be placed in a NixOS closure and
called by glibc software. The planned LineageOS container or a narrower
Halium/libhybris bridge must expose each required service deliberately.

## DTB state and the X13s comparison

The public `.3001` inputs are enough to reconstruct a strong vendor-kernel
candidate:

1. `boot.img` contains an Android DT table v0 with one base FDT.
2. `dtbo.img` contains ten overlays.
3. The OnePlus virtual-A/B defconfig orders six dummy overlays followed by
   project overlays; index 7 is `oplus6893_21881`, the Karen project family.
4. Applying that overlay to the stock base succeeds and yields a deterministic
   309,748-byte FDT.

The resolved static tree contains MT6893 clock and power descriptions,
MediaTek M4U/IOMMU ports, UFS, USB, MMC, display, SCP/SSPM/ADSP and extensive
OPlus project data. It is a useful DTB for the vendor 4.19 kexec path. It is
not yet the authoritative live tree: LK may still fix up memory, `/chosen`,
serial data and reserved regions before entering Linux.

The next evidence gate is a private capture of `/sys/firmware/fdt` from the
rooted control system. Keep the raw capture off Git and off the remote build
host because bootloader fixups can contain identifiers or random seeds.
Commit only a scrubbed structural diff and independently reproducible public
properties.

The X13s analogy is directionally correct but skips a major layer. Upstream
Linux already has an SC8280XP SoC DTSI and broad clock, interconnect, UFS,
USB PHY, display, GPU, audio and remoteproc driver support; the X13s DTS
mainly describes how that supported SoC is wired on one product. At the
audited upstream revision, MT6893 has only seven specifically named files:

```text
Documentation/devicetree/bindings/pinctrl/mediatek,mt6893-pinctrl.yaml
arch/arm64/boot/dts/mediatek/mt6893-pinfunc.h
drivers/pinctrl/mediatek/pinctrl-mt6893.c
drivers/pinctrl/mediatek/pinctrl-mtk-mt6893.h
drivers/pmdomain/mediatek/mt6893-pm-domains.h
include/dt-bindings/memory/mediatek,mt6893-memory-port.h
include/dt-bindings/power/mediatek,mt6893-power.h
```

There is no upstream MT6893 SoC DTSI, Karen DTS, MT6893 clock-controller
implementation or complete interconnect/display/UFS/USB/audio/GPU/modem
integration. A DTB can describe registers, interrupts, clocks, IOMMU stream
IDs and power domains, but only a matching driver can act on that
description. The vendor DTB can therefore boot the vendor kernel long before
it can boot a current upstream kernel.

## Source-built 4.19 control kernel

The earlier compile blocker is closed. The official module tree contains the
required `vendor/oplus` sources. The flake now combines that tree with the
official kernel, applies small reviewed compiler/API fixes and restores four
generated GPL-2.0 DCT outputs from the community kernel only after verifying
that their OnePlus DWS inputs are byte-identical.

Run and export it without handling a store path:

```bash
nix run .#karen-source-kernel-bootimage -- \
  ./result-karen-source-kernel-bootimage
```

The clean build on the optional owner build host completed successfully in
11 minutes and produced:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `boot.img` | 67,108,864 | `4420a5a503df9d96f8737ab6768b7ac7eb031b60e4d5f406d32aa703610c04ac` |
| `kernel` | 18,821,574 | `0ec542e43f759a6d69eb81a1995ef056052b9b2655c6a1a43c6243c117e7b3a6` |
| `kernel.config` | 174,687 | `eb1876edb00b7b1a9d615792ab3f49c9fb1e71e44d76f4ead5df2da27686c673` |

The effective configuration has `CONFIG_KEXEC=y`, `CONFIG_KEXEC_CORE=y`,
devtmpfs, file handles and the requested cgroup controllers built in. The
packaged DTB remains byte-identical to the exact stock DTB.

This output is deliberately not a flash candidate. Its diagnostic recovery
ramdisk has `ro.adb.secure=0`, is unrooted and has no owner ADB key. It has
not been booted, paired with the final AVB metadata or converted to the
requested Magisk/root-full control image. The normal `audit-boot` app also
correctly rejects its non-stock kernel before any flash action.

The secure key-bound follow-up target subsequently completed in 10 minutes
31 seconds:

```bash
nix run --impure .#karen-source-kernel-keybound-bootimage -- \
  ./result-karen-source-kernel-keybound-bootimage
```

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `boot.img` | 67,108,864 | `f1bd81e3f78674c2c8a1f7153a70ad98a4af7765b6779534d9d7e5c05a257cc1` |
| `kernel` | 18,821,581 | `89827d94738926488fbba1d2ebf2c3bb544b6bb44736a6ea0f427fb6712e1325` |
| `kernel.config` | 174,687 | `eb1876edb00b7b1a9d615792ab3f49c9fb1e71e44d76f4ead5df2da27686c673` |

Its effective config is byte-identical to the diagnostic build. The compressed
kernel differs because the upstream build embeds its autogenerated build time.
The source-kernel boot audit passed with the explicit kernel hash and
`--allow-embedded-adb-key`: the ramdisk is authenticated, SELinux defaults to
enforcing, the OLED-breaking init power-cycle is absent and the DTB hash is
the exact stock
`3f556b701b84247e529d4c05a46c7e45c9e29cffd4aca2c18822290de8d603c6`.
This closes the secure boot-image construction gate, not the install gate:
the candidate still needs a complete matching Lineage userspace/AVB bundle,
the root-full patch and a live boot/runtime audit.

The complete source-kernel image target keeps the exact stock `vendor` and
`odm` images. Lineage's source-kernel build therefore routes only the modules
built alongside the new kernel into `system/lib/modules`. The control kernel
also trusts the public module-signing certificate derived from the exact
pinned stock boot image; no stock private key is present or required.

Signature trust alone does not prove ABI compatibility. Source-kernel
artifacts consequently export `Module.symvers` and `kernel.release`. The
normal full-image audit extracts all ten pinned stock MediaTek modules,
verifies each PKCS#7 signature against that public certificate, checks the
kernel release and compares every imported modversion CRC against the new
kernel plus the complete stock module set. A mismatch is a pre-flash failure,
not a runtime experiment.

## Concrete remaining gates

### First headless NixOS through vendor 4.19

1. Combine the audited secure key-bound source-kernel boot image with the
   already validated complete Lineage userspace and matching AVB images.
2. Integrate Magisk and the requested root-full profile without reusing the
   insecure diagnostic recovery properties.
3. Audit, flash only the bounded boot/AVB pair and prove a normal Lineage boot
   plus basic storage, USB, charging and thermal behavior.
4. Verify the running effective config and the `kexec_load` syscall.
5. Capture and scrub the live resolved FDT, then compare it with the static
   base-plus-`21881` reconstruction.
6. Test kexec load/unload before executing anything.
7. Build a minimal Mobile NixOS stage-1 initrd with UFS/root discovery,
   systemd requirements and authenticated USB access.
8. Execute an initrd-only diagnostic jump, then add the NixOS closure.

No current-mainline kernel is required to complete those gates.

### Native boot with vendor 4.19

After kexec succeeds, assemble the same tested kernel, resolved DTB and NixOS
initrd in Karen's header-v2 64 MiB boot format and pair it with audited AVB.
Choose rootfs placement only after the partition and rollback design is
reviewed. This is still a vendor-kernel NixOS port, but it removes Android
from PID 1 and proves cold boot independently of kexec.

### Current upstream kernel

Build the missing MT6893 platform support by subsystem:

- SoC DTSI and Karen board DTS;
- clocks, reset, power domains and interconnect;
- interrupt, pinctrl and IOMMU/M4U integration;
- UFS and USB/PHY;
- display, GPU and touch;
- remote processors, audio and modem transports;
- thermal, charging, suspend and remaining OPlus devices.

Mine the exact stock-resolved tree, the OnePlus 4.19 source, the older MT6893
donor BSP and later MediaTek kernels for facts. Implement against current
upstream subsystem APIs. Do not attempt a textual 4.19-to-current rebase and
do not treat a decompiled vendor DTS as an upstream-quality binding.

## Publication boundary

Publish only:

- source, patches, manifests, hashes and extraction instructions;
- redistributable outputs where every component's licence permits it;
- structural DT and runtime facts scrubbed of identifiers;
- a firmware derivation that fetches the pinned public OTA rather than
  committing its proprietary payload.

Never publish or send to the optional build host any raw live FDT before
review, ADB private key, Magisk owner secret, `nvram`, `nvdata`, `nvcfg`,
`persist`, `proinfo`, `protect*`, radio contents or calibration data.
