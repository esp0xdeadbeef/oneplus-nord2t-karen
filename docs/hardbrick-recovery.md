<!-- SPDX-License-Identifier: MIT -->

# Hardbrick recovery

This document separates recovery levels that are often all called “unbrick”.
Android, fastbootd, bootloader-fastboot and the transient preloader interface
have been observed on this host, but a complete BROM/DA stock flash round-trip
is still pending.

## Recovery ladder

1. **Android/stock recovery:** ADB is available, or signed OxygenOS recovery
   can apply the full `.3001` OTA.
2. **Userspace fastbootd:** `adb reboot fastboot` exposes a secure A/B
   fastbootd interface. It can inspect dynamic partitions. The bootloader is
   now unlocked.
3. **Bootloader fastboot:** proven through `fastboot reboot bootloader` from
   fastbootd, but only over a cable connected directly to the laptop. Behind
   the Lenovo dock the black OPlus screen showed `DB: product name is match`
   without a host USB device. Direct USB exposed `is-userspace: no`, allowed
   the bootloader unlock and successfully wrote an audited Magisk control to
   active `boot_a`. Temporary `fastboot boot` is not usable: transferred
   images return through `lk_crash`.
4. **OPlus/MediaTek preloader:** `adb reboot edl` transiently exposes USB
   `22d9:0006`. A read-only mtkclient target-configuration handshake now
   succeeds. After a completed handshake the phone remains on the black
   preloader screen; Power plus Volume Up for roughly ten seconds restores a
   normal stock boot.
5. **MediaTek Boot ROM/service flashing:** not yet proven. A true hardbrick
   restore requires a compatible signed Download Agent or a working
   `mtkclient` exploit, correct GPT/scatter data and anti-rollback-safe
   firmware. Public service packages are third-party mirrors and must not be
   trusted or flashed until their contents and signatures have been audited.

The fact that preloader enumerates is valuable but does not prove flash access.
Current OPlus MediaTek devices can require DAA, SLA and remote service
authentication.

## Verified preloader probe

The current Nixpkgs mtkclient package identified hardware code `0x950` as
`MT6891/MT6893 (Dimensity 1200)`. The exact connected phone reported:

- Secure Boot Check enabled;
- Download Agent Authentication enabled;
- Serial Link Authentication disabled;
- no root certificate requirement;
- no separate memory-read or memory-write authentication flag;
- no block on command `0xC8`.

The successful command used raw USB and deliberately skipped the watchdog
write:

```bash
nix run .#probe-preloader
```

mtkclient normally prints the device-unique ME ID and SoC ID and writes them
to `hwparam.json`. The wrapper runs it in a temporary directory, prints only
the non-unique security flags and deletes the raw output. Do not run the bare
command from the repository root or publish its output.

This proves the preloader control handshake, not Download Agent execution or
UFS access. DAA remains enabled. The next destructive-recovery gate is to load
a compatible, reviewable DA without writing storage, then read the GPT twice
and compare hashes.

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

Rooted readback proved that both absent live `vendor_boot` partitions are
entirely zero-filled. It also mapped the active slot's non-unique boot
partitions and verified the padded DTBO/AVB contents against `.3001`. Slot B
is older, with a 2024-12 boot header, and is not a current restore source.

Never replace or publish those device-unique partitions. If read access through
preloader is proven, encrypted offline backups may be made locally before any
deep flashing experiment.

## Host preparation

The `l-esp` NixOS configuration grants the logged-in user access only to the
standard MediaTek USB vendor ID and the OPlus preloader product ID:

```nix
SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0660", GROUP="users", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", ATTR{idProduct}=="0006", MODE="0660", GROUP="users", TAG+="uaccess"
SUBSYSTEM=="tty", KERNEL=="ttyACM[0-9]*", ATTRS{idVendor}=="22d9", ATTRS{idProduct}=="0006", MODE="0660", GROUP="users", TAG+="uaccess"
```

That host configuration was applied and checked on `l-esp`. Raw USB is used
for the short preloader probe because the ACM device exists for less than a
second before the normal watchdog path resumes. Do not begin with a write,
erase, format, whole-flash or preloader write command.

## Required proof before relying on hardbrick restore

- GPT can be read twice with identical hashes.
- Both UFS boot regions and the active GPT partition table are backed up.
- Security flags and any required DA/auth path are recorded.
- every `.3001` firmware image is mapped to its physical slot name without
  guessing; boot/DTBO/AVB on slot A are mapped, while the remaining
  boot-chain mapping is incomplete.
- Anti-rollback state is understood; older `.605` or Android 12 firmware is
  not written merely because a public service package exists.
- A read-back comparison verifies every written non-unique partition.
- Android boots stock with green Verified Boot after relocking.

Until those checks pass, fastbootd, bootloader-fastboot and the pinned
stock-boot restoration are tested softbrick routes, while true BROM recovery
remains an active bring-up item.
