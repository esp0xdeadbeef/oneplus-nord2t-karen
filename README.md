<!-- SPDX-License-Identifier: MIT -->

# OnePlus Nord 2T (`CPH2399` / `karen`)

Reproducible privacy, inventory and recovery tooling for the European OnePlus
Nord 2T 5G.

This is not a ROM and it does not contain flashable images. As of 2026-07-24,
`CPH2399` is not officially supported by GrapheneOS or LineageOS. The safest
maintainable configuration currently available for this phone is an up-to-date
official OxygenOS installation, followed by reversible package hardening. The
bootloader of the test phone is currently unlocked for recovery and LineageOS
bring-up.

The scripts refuse to operate on a device unless ADB reports both:

- model `CPH2399`;
- product device `OP557AL1`.

Do not flash builds for `oscaro`, `avicii` or `denniz`. Those are different
phones.

## Current state

The inspected phone currently runs `CPH2399_14.0.0.3001(EX01)` with the
2026-06-01 security patch. The official full EU OTA was independently verified
and installed through OxygenOS Local install on 2026-07-24. Before the later
bootloader-unlock wipe, the package changes of a reversible privacy profile
were tested:

- Aurora Store 4.8.3 from F-Droid was installed;
- Play Store, Play services and Google Services Framework are disabled for the
  owner profile;
- 21 conservative telemetry targets and 24 Google-facing targets are disabled;
- the bootloader was later unlocked, so Verified Boot now reports orange.

The owner subsequently confirmed that Aurora Store was not usable in that
configuration. The exact failure cause has not been isolated, so the profile
is not a validated daily setup even though its package-state changes and
restore actions worked.

The unlock wipe reset that user-0 package profile. The current audit finds no
Aurora installation and all 21 hardening plus 24 Google-facing targets at
their stock default state. Leave that baseline in place unless the Aurora
failure or another app-distribution route is tested separately.
The phone booted successfully from the updated A/B slot. SELinux remains
enforcing, storage remains encrypted, and the telephony, SIM, connectivity,
Wi-Fi, Bluetooth, camera and NFC system services are present. Calls, SMS,
mobile data, Wi-Fi association, Bluetooth pairing, camera output, NFC, push
notifications, banking apps and navigation still need real-world testing by
the owner.

The bootloader was unlocked and userdata was wiped on 2026-07-24 for recovery
bring-up. Stock OxygenOS still boots from slot `a`, but Verified Boot now
reports orange/unlocked instead of green/locked. The working unlock path was
fastbootd -> bootloader-fastboot over a cable connected directly to the
laptop; bootloader-fastboot did not enumerate behind the Lenovo dock. See the
[tested unlock procedure](docs/recovery.md#tested-bootloader-unlock).

The full root stack can mask Android's `ro.boot.*` property view as
`green/locked` for application compatibility. The raw kernel command line
still reports `androidboot.vbmeta.device_state=unlocked` and
`androidboot.verifiedbootstate=orange`. The audit and stock-boot helpers prefer
that kernel source when approved root can read it and otherwise fail
conservatively; bootloader-fastboot remains the final authority before a
write.

For an unmasked debugging baseline, the test phone was subsequently restored
to exact stock `boot_a`, verified without root, and rooted again with only the
pinned Magisk 30.7 workflow. Zygisk is disabled; Vector, Shamiko and Systemless
Hosts are absent; Hide My Applist and AdAway are uninstalled. Both Android's
property view and the raw kernel command line now report `unlocked/orange`.

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

The official Magisk v30.7 APK is also a non-flake input. Its release artifact
and the stock `.3001` boot image derived from the OTA are both locked by
`flake.lock` and checked against hard-coded size and SHA-256 pins before the
root workflow uses them.

The optional full rooted stack adds four more locked upstream artifacts:
Vector 2.0, Shamiko 1.2.5, Hide My Applist 3.8 and AdAway 6.1.4. The helper
checks their exact byte sizes and SHA-256 values in addition to Nix's lock
hashes; it never resolves a “latest” URL at runtime.

The repository then adds the local `karen` tree without committing proprietary
or stock-derived binaries. There are three useful build paths:

```bash
# Derive the stock kernel, DTB and DTBO and assemble the device tree.
nix build .#karen-device-tree

# Realize the locked Lineage source graph and build boot.img in a Nix sandbox.
nix build .#karen-bootimage

# Reproduce the current official-source kernel gate.
nix build .#karen-source-kernel-bootimage

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

The source-kernel target pins OnePlus's corresponding MT6893 kernel and
MediaTek module repositories exactly. It currently fails closed because the
published kernel contains links to a substantial `vendor/oplus` source layer
that OnePlus did not include. The reproducible failure is documented in the
[LineageOS port assessment](docs/lineage-port.md); the working recovery and
initial full-system bring-up therefore retain the verified `.3001` stock
kernel while that source gate remains unresolved.

The pinned build completed successfully on `s-tau` and its resulting
recovery-as-boot image passed the repository's structural audit. Its kernel
and DTB are byte-identical to `.3001` stock, while the ramdisk contains the
expected Lineage Recovery, fastbootd, first-stage fstab, virtual A/B
`snapuserd` and SELinux policy. Temporary `fastboot boot` transferred
completely but returned to stock with boot reason `lk_crash`, so the corrected
image was written only to inactive `boot_b` after its exact stock contents had
been saved.

That inactive-slot probe booted Lineage Recovery successfully. Its display and
ADB worked, ADB ran as root in recovery, the device reported slot `b`, and the
first-stage ramdisk files were present. No user-data or dynamic partition was
flashed. The phone was then rebooted to bootloader-fastboot, slot `a` was made
active, and the saved original `boot_b` was restored and verified byte for
byte. Stock `.3001` subsequently booted normally with SELinux enforcing and
the separately tested Magisk root on `boot_a` still intact. The recovery
remains an unsigned bring-up image with deliberately insecure ADB; it is not an
installable ROM. See the
[LineageOS port assessment](docs/lineage-port.md) for the current gates and
bring-up sequence.

A Magisk-patched stock control image confirmed the loader behavior: temporary
`fastboot boot` returned to slot A with `lk_crash` and no Magisk process, while
writing the same audited image to active `boot_a` booted normally and started
`magiskd`. Magisk's additional setup then completed and an explicitly approved
ADB shell returned `uid=0(root)`. Consequently, a successful transfer followed
by transport loss is not evidence that this loader executed a temporary image.

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

Apply the experimental de-Googled profile only after accounting for the
observed unusable Aurora configuration:

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

After that probe, an experimental, more invasive but storage-read-only GPT
gate is available:

```bash
nix run .#read-gpt
```

It attempts to upload the pinned MT6893 mtkclient support to RAM, then requires
two byte-identical UFS GPT reads before it stores one private local copy
outside the repository. It never issues a write, erase or format command. The
first hardware attempts did not produce GPT bytes and one left the phone on
the black preloader screen until the Power plus Volume Up recovery chord was
used. This route is not proven and should not be treated as stock-herstel.

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

Build a verified Magisk-patched stock boot image without flashing it:

```bash
nix run .#stock-root
```

Temporarily boot it, or explicitly make it persistent on only the active slot:

```bash
nix run .#stock-root -- --boot
nix run .#stock-root -- --persist
```

Install the complete pinned root stack, optionally adding exact apps or
processes to the Magisk denylist consumed by Shamiko:

```bash
nix run .#stock-root-full -- --persist
nix run .#stock-root-full -- --persist \
  --denylist com.example.app \
  --denylist com.example.app:isolated_process
```

This enables Zygisk, installs Vector, Shamiko, Hide My Applist and AdAway, and
creates Magisk's Systemless Hosts module. It deliberately leaves Magisk's
denylist enforcement off because Shamiko requires that setting while reading
the configured list itself. No app is added to the list by default. Hide My
Applist must still be enabled and scoped in Vector; AdAway must still be
opened once to select root-based blocking and apply its hosts sources.

Restore the exact pinned stock boot image to the active slot:

```bash
nix run .#stock-unroot -- --persist
```

The persistent commands require an unlocked bootloader and an on-device-style
confirmation unless `--yes` is supplied. They refuse any phone or installed
build other than the tested `CPH2399` / `OP557AL1` `.3001` baseline. See
[Stock root and unroot](docs/stock-root.md) before using either write path.
For a bootloop where Android/ADB is unavailable, `stock-unroot` also has a
separately gated `--from-fastboot` recovery mode.

The default firmware directory is
`$XDG_CACHE_HOME/nord2t-recovery`, falling back to
`$HOME/.cache/nord2t-recovery`. Firmware, APKs, dumps and snapshots are ignored
by Git.

## Documentation

- [Device inventory](docs/device.md)
- [Privacy profile](docs/privacy.md)
- [OS choice](docs/os-options.md)
- [Update and recovery](docs/recovery.md)
- [Stock root and unroot](docs/stock-root.md)
- [Hardbrick recovery](docs/hardbrick-recovery.md)
- [TWRP image audit](docs/twrp-audit.md)
- [LineageOS port assessment](docs/lineage-port.md)

Run all repository checks with:

```bash
nix flake check --all-systems
```

Bootloader unlocking erases user data and gives up the stock Verified Boot
trust state. The root helpers deliberately limit writes to the active boot
slot and always retain a pinned stock-unroot route; they do not make the
experimental LineageOS image safe to flash.
