<!-- SPDX-License-Identifier: MIT -->

# OnePlus Nord 2T (`CPH2399` / `karen`)

Reproducible privacy, inventory and recovery tooling for the European OnePlus
Nord 2T 5G.

This is not a ROM and it does not contain flashable images. As of 2026-07-24,
`CPH2399` is not officially supported by GrapheneOS or LineageOS. The safest
maintainable configuration currently available for this phone is an up-to-date
official OxygenOS installation with the stock bootloader locked, followed by
reversible package hardening.

The scripts refuse to operate on a device unless ADB reports both:

- model `CPH2399`;
- product device `OP557AL1`.

Do not flash builds for `oscaro`, `avicii` or `denniz`. Those are different
phones.

## Current state

The inspected phone currently runs `CPH2399_14.0.0.3001(EX01)` with the
2026-06-01 security patch. The official full EU OTA was independently verified
and installed through OxygenOS Local install on 2026-07-24. A reversible
privacy profile is active:

- Aurora Store 4.8.3 from F-Droid is installed;
- Play Store, Play services and Google Services Framework are disabled for the
  owner profile;
- 21 conservative telemetry targets and 24 Google-facing targets are disabled;
- the bootloader remains locked and Verified Boot remains green.

The phone booted successfully from the updated A/B slot. SELinux remains
enforcing, storage remains encrypted, Aurora starts, and the telephony, SIM,
connectivity, Wi-Fi, Bluetooth, camera and NFC system services are present.
Calls, SMS, mobile data, Wi-Fi association, Bluetooth pairing, camera output,
NFC, push notifications, banking apps and navigation still need real-world
testing by the owner.

The bootloader was unlocked and userdata was wiped on 2026-07-24 for recovery
bring-up. Stock OxygenOS still boots from slot `a`, but Verified Boot now
reports orange/unlocked instead of green/locked. The working unlock path was
fastbootd -> bootloader-fastboot over a cable connected directly to the
laptop; bootloader-fastboot did not enumerate behind the Lenovo dock. See the
[tested unlock procedure](docs/recovery.md#tested-bootloader-unlock).

Disabling Play services breaks or degrades Firebase push, Google login, Wallet,
Android Auto, RCS, Play Integrity and apps that require Google APIs. The helper
therefore provides restore actions. It deliberately keeps critical telephony,
emergency, network, permission, OTA, camera, WebView and input components.

## Reproducible LineageOS bring-up

The experimental LineageOS 21 recovery build has two independent pinned source
layers:

- `stock-firmware-3001` is the exact official EU OTA, locked by `flake.lock`
  and checked again against the whole-file and partition hashes in
  `firmware/`;
- `robotnix` is locked to an exact revision and imports its generated
  LineageOS `repo.lock`. That lock is Robotnix's Nix equivalent of
  `repo manifest -r`: every Android project has a fixed Git commit and Nix
  content hash. The flake deterministically removes only the unrelated
  TheMuppets vendor trees for other phones before evaluation; Karen's stock
  inputs come from the separately verified OTA.

The repository then adds the local `karen` tree without committing proprietary
or stock-derived binaries. There are three useful build paths:

```bash
# Derive the stock kernel, DTB and DTBO and assemble the device tree.
nix build .#karen-device-tree

# Realize the locked Lineage source graph and build boot.img in a Nix sandbox.
nix build .#karen-bootimage

# Compare a candidate with the pinned stock boot image and inspect its ramdisk.
nix run .#audit-boot -- ./result/boot.img

# Enter the FHS environment for faster, mutable Android-tree iteration.
nix run .#android-fhs
```

The first clean build of `karen-bootimage` must fetch and realize the complete
LineageOS/AOSP source graph. Those repositories become ordinary immutable Nix
store paths and are reused by later builds. A large Nix-capable machine such as
`s-tau` can run the same flake over SSH; no declarative host exception or
machine-specific build configuration is part of this repository.

The pinned build completed successfully on `s-tau` and its resulting
recovery-as-boot image passed the repository's structural audit. Its kernel
and DTB are byte-identical to `.3001` stock, while the ramdisk contains the
expected Lineage Recovery, fastbootd, fstab and SELinux policy. The first
temporary RAM boot transferred completely, then lost fastboot transport and
eventually returned to stock with boot reason `lk_crash`; it did not yet
provide a persistent recovery shell. The next recovery-only probe deliberately
disables ADB authentication so this freshly wiped device can expose early
bring-up logs. The audit rejects that debug setting unless
`--allow-insecure-adb` is explicitly supplied. This remains an unsigned test
image, and exact stock-slot restoration must be proven before anything is
flashed persistently. See the
[LineageOS port assessment](docs/lineage-port.md) for the current gates and
bring-up sequence.

## Use

Enter the development shell:

```bash
nix develop
```

Inspect the connected phone without modifying it:

```bash
nix run .#privacy -- audit
nix run .#privacy -- inventory
```

Apply the currently selected de-Googled profile:

```bash
nix run .#privacy -- degoogle
```

Restore Google components or all conservative hardening targets:

```bash
nix run .#privacy -- restore-google
nix run .#privacy -- restore-hardening
```

Create a privacy-filtered, rootless device snapshot:

```bash
nix run .#snapshot
```

Probe only the MediaTek preloader security flags, while deleting the raw
identifier-bearing output:

```bash
nix run .#probe-preloader
```

This reboots Android into the black OPlus preloader screen. No flash command
is sent, but the phone must afterwards be restarted by holding Power and
Volume Up for about ten seconds.

Verify locally cached official recovery packages, including hashes, metadata,
payload hashes, OTA whole-file signatures and signer certificate:

```bash
nix run .#verify-firmware
nix run .#verify-firmware -- --device-cert
```

Extract the exact `.3001` boot metadata and proprietary partitions without
root, loop mounts or a GitHub firmware mirror:

```bash
nix run .#extract-stock -- --profile boot
nix run .#extract-stock -- --profile blobs
nix run .#extract-stock -- --profile firmware
nix run .#extract-stock -- --profile stock
```

The extractor verifies the full OTA and every resulting image against
[`firmware/partitions-3001.json`](firmware/partitions-3001.json), then
rootlessly expands all EROFS blob partitions when requested. `stock` contains
all 34 images present in the payload; it is not by itself a BROM restore
package because the OTA has no GPT, Download Agent, authentication material or
`vendor_boot`. For a clean Nix-store copy of the same official OPlus CDN
object, use:

```bash
nix build .#firmware-3001 --no-link --print-out-paths
```

That fixed-output derivation is roughly 5.6 GB. Pass its printed path as the
final argument to `nix run .#extract-stock -- ...` if the normal cache is not
being used.

The default firmware directory is
`$XDG_CACHE_HOME/nord2t-recovery`, falling back to
`$HOME/.cache/nord2t-recovery`. Firmware, APKs, dumps and snapshots are ignored
by Git.

## Documentation

- [Device inventory](docs/device.md)
- [Privacy profile](docs/privacy.md)
- [OS choice](docs/os-options.md)
- [Update and recovery](docs/recovery.md)
- [Hardbrick recovery](docs/hardbrick-recovery.md)
- [TWRP image audit](docs/twrp-audit.md)
- [LineageOS port assessment](docs/lineage-port.md)

Run all repository checks with:

```bash
nix flake check --all-systems
```

No unlock, root or flash command is automated by this repository. Bootloader
unlocking erases user data and gives up the stock Verified Boot trust state.
The current extraction work makes a port reproducible; it does not make an
image safe to flash. Only add such a workflow after a bootable, auditable image
and exact recovery path exist for `CPH2399`.
