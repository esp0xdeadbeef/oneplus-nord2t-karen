<!-- SPDX-License-Identifier: MIT -->

# Hardbrick recovery

This document separates recovery levels that are often all called “unbrick”.
Android, fastbootd and the transient preloader interface have been observed on
this host, but a complete destructive stock flash round-trip is still pending.

## Recovery ladder

1. **Android/stock recovery:** ADB is available, or signed OxygenOS recovery
   can apply the full `.3001` OTA.
2. **Userspace fastbootd:** `adb reboot fastboot` exposes a secure A/B
   fastbootd interface. It can inspect dynamic partitions. Flashing remains
   blocked while the bootloader is locked.
3. **Bootloader fastboot:** not currently exposed over USB. Both
   `adb reboot bootloader` and `fastboot reboot bootloader` enter the black
   OPlus screen showing `DB: product name is match`, without a host fastboot
   device. Power plus Volume Up for roughly ten seconds, followed by Power,
   restores a normal boot.
4. **OPlus/MediaTek preloader:** `adb reboot edl` transiently exposes USB
   `22d9:0006`, then the watchdog returns to Android. This was observed
   read-only. The host needs the repository's restricted udev rule before
   `mtkclient` can test the handshake.
5. **MediaTek Boot ROM/service flashing:** not yet proven. A true hardbrick
   restore requires a compatible signed Download Agent or a working
   `mtkclient` exploit, correct GPT/scatter data and anti-rollback-safe
   firmware. Public service packages are third-party mirrors and must not be
   trusted or flashed until their contents and signatures have been audited.

The fact that preloader enumerates is valuable but does not prove flash access.
Current OPlus MediaTek devices can require DAA, SLA and remote service
authentication.

## Verified stock material

The official full EU `.3001` OTA contains 34 partitions. They include:

- stock `boot`, `dtbo` and all three AVB metadata images;
- `system`, `system_ext`, `product`, `vendor`, `odm` and eight OPlus logical
  partitions;
- `preloader_raw`, `lk`, modem, TEE and MediaTek coprocessor firmware.

Every image's size and SHA-256 is pinned in
[`partitions-3001.json`](../firmware/partitions-3001.json). Reproduce the set
with:

```bash
nix run .#extract-stock -- --profile stock
```

The payload does **not** include:

- GPT primary/backup headers or a scatter file;
- `vendor_boot_a` or `vendor_boot_b`;
- an OPlus Download Agent, authorization certificate or service login;
- device-unique `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`, `protect*`
  and calibration data.

Never replace or publish those device-unique partitions. If read access through
preloader is proven, encrypted offline backups may be made locally before any
deep flashing experiment.

## Host preparation

The `l-esp` NixOS configuration grants the logged-in user access only to the
standard MediaTek USB vendor ID and the OPlus preloader product ID:

```nix
SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0660", GROUP="users", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", ATTR{idProduct}=="0006", MODE="0660", GROUP="users", TAG+="uaccess"
```

Apply that host configuration outside this repository before repeating the
read-only `mtkclient gettargetconfig` test. Do not begin with a write, erase,
format, whole-flash or preloader command.

## Required proof before relying on hardbrick restore

- `mtkclient gettargetconfig` or the signed service tool recognizes this exact
  device without revealing identifiers in logs.
- GPT can be read twice with identical hashes.
- Both UFS boot regions and the active GPT partition table are backed up.
- Security flags and any required DA/auth path are recorded.
- `.3001` partition images are mapped to the physical slot names without
  guessing.
- Anti-rollback state is understood; older `.605` or Android 12 firmware is
  not written merely because a public service package exists.
- A read-back comparison verifies every written non-unique partition.
- Android boots stock with green Verified Boot after relocking.

Until those checks pass, fastbootd plus signed stock recovery is the tested
softbrick route, while true BROM recovery remains an active bring-up item.
