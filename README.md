<!-- SPDX-License-Identifier: MIT -->

# OnePlus Nord 2T (`CPH2399` / `karen`)

Reproducible stock recovery and unofficial LineageOS bring-up tooling for the
European OnePlus Nord 2T 5G.

This repository does not commit flashable images. As of 2026-07-25, `CPH2399`
is not officially supported by GrapheneOS or LineageOS. The local port now
boots LineageOS 21 on the test phone, but remains a private bring-up build
rather than a supported release. The exact official OxygenOS
`CPH2399_14.0.0.3001(EX01)` inputs and bounded rollback paths remain pinned.

For the current resumable checkpoint, active owner paths, mandatory next gates
and rollback order, see [`docs/follow-up.md`](docs/follow-up.md). The named
`s-tau` host is only the owner's optional compilation offload; see the
[remote-build-host guide](docs/remote-builder.md).

The scripts refuse to operate on a device unless ADB reports both:

- model `CPH2399`;
- product device `OP557AL1`.

Do not flash builds for `oscaro`, `avicii` or `denniz`. Those are different
phones.

## Current state

The test phone currently boots exact OxygenOS
`CPH2399_14.0.0.3001(EX01)` on slot A after a complete Lineage-to-stock
rollback. The bootloader is relocked, Verified Boot reports green, encryption
and SELinux enforcing are active, and the runtime contains no Magisk process,
package or `su` command. Returning from Lineage userdata required a stock
factory reset; the subsequent bootloader lock performed its own mandatory
wipe.

The earlier Lineage boot exercised display, touch, camera, audio and internet
successfully. Its passive runtime audit reported the expected framework,
binder services, core processes, input devices and DRM node. Calls, SMS,
mobile data, Wi-Fi association, Bluetooth pairing, NFC, GPS/navigation,
suspend/resume, charging, push notifications and banking-app behavior still
need explicit real-world checks after the next audited Lineage install.

The official full EU `.3001` OTA was independently verified and installed
through OxygenOS Local install on 2026-07-24 before Lineage bring-up.

The bootloader was unlocked and userdata was wiped on 2026-07-24 for recovery
bring-up. Exact stock rollback and relock were completed on 2026-07-25.
Stock recovery-fastbootd supplied the working reverse path and all restored
images came from the pinned public OTA; OPlus, radio, calibration and
persistent partitions remained untouched. The working unlock path was
fastbootd -> bootloader-fastboot over a cable connected directly to the
laptop; bootloader-fastboot did not enumerate behind the Lenovo dock. See the
[tested unlock and relock procedures](docs/recovery.md#tested-bootloader-unlock).

The full root stack can mask Android's `ro.boot.*` property view as
`green/locked` for application compatibility. That masking was not used for
the current result: stock directly reports `green`, `locked` and
`flash.locked=1`, and bootloader-fastboot independently reported
`unlocked=no`. The audit and stock-boot helpers still fail conservatively when
they cannot establish the underlying boot state.

On the former stock baseline, an exact stock `boot_a` unroot/root round trip
was verified with pinned Magisk 30.7. The separate Lineage helpers below keep
minimal root equally plain: Zygisk and concealment modules remain disabled
unless the full profile is explicitly selected.

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

The optional Google-app profile pins the official Android 14 arm64
MindTheGapps release separately. It is not part of the vanilla image and is
never selected implicitly. Aurora Store is likewise a separate pinned user
app, so installing it does not toggle or remove Android packages.

## Host-local ADB key

Private headless builds can bind recovery ADB to one host key without putting
plaintext key material in Git. Run this as the normal desktop user:

```bash
nix run .#adb-key-generator
```

The command is deliberately idempotent. If the host-specific SOPS file is
absent, it imports an existing `~/.android/adbkey`; it generates a new ADB key
only if neither copy exists. If the encrypted and local keys differ, it stops
without overwriting either. If needed for a new user, it also creates a
mode-0600 age identity under `~/.config/sops/age/`; that bootstrap identity
must be backed up separately. The committed `l-esp` secret is decryptable only
with that host user's age identity.

The private ADB key remains on the phone host. When using the optional remote
workflow, only its public half may be copied to the build host as
`KAREN_DEBUG_ADB_KEYS`; vanilla builds require neither file. Other owners get
their own isolated `secrets/HOST-USER-adb-host-key.age` by running the same
command on their phone/build host.

The repository then adds the local `karen` tree without committing proprietary
or stock-derived binaries. There are three useful build paths:

```bash
# Derive the stock kernel, DTB and DTBO and assemble the device tree.
nix build .#karen-device-tree

# Realize the locked Lineage source graph and build boot.img in a Nix sandbox.
nix build .#karen-bootimage

# Build the full bring-up image set with verified stock vendor/odm.
nix build .#karen-full-images

# Reproduce the current official-source kernel gate.
nix build .#karen-source-kernel-bootimage

# Compare a candidate with the pinned stock boot image and inspect its ramdisk.
nix run .#audit-boot -- ./result/boot.img

# Enter the FHS environment for faster, mutable Android-tree iteration.
nix run .#android-fhs
```

The first clean build of `karen-bootimage` must fetch and realize the complete
LineageOS/AOSP source graph. Those repositories become ordinary immutable Nix
store paths and are reused by later builds. A sufficiently large local machine
can run every target directly. The owner optionally uses `s-tau` over SSH
because `l-esp` ran out of memory during full Android builds; no host exception
or machine-specific builder configuration is part of this repository. See the
[optional remote-build-host workflow](docs/remote-builder.md).

The source-kernel target pins OnePlus's corresponding MT6893 kernel and
MediaTek module repositories exactly. It currently fails closed because the
published kernel contains links to a substantial `vendor/oplus` source layer
that OnePlus did not include. The reproducible failure is documented in the
[LineageOS port assessment](docs/lineage-port.md); the working recovery and
initial full-system bring-up therefore retain the verified `.3001` stock
kernel while that source gate remains unresolved.

`karen-full-images` is a bring-up bundle, not yet a flashable release. Unlike
the recovery probe it does not enable insecure ADB. It builds Lineage `boot`,
`system`, `system_ext` and `product`, creates the matching AVB metadata, and
passes through byte-identical `.3001` `vendor` and `odm` images derived from
the verified OTA. The full build also uses stock's complete first-stage mount
table while `TARGET_RECOVERY_FSTAB` remains the minimal recovery-safe table.
Audit all nine outputs before considering a hardware write:

```bash
nix run .#audit-lineage-images -- ./result
```

The audit verifies the boot structure, authenticated ADB, complete AVB chain,
byte-exact stock `vendor` and `odm`, and the preserved live standard-image
budget. Passing it is necessary but does not by itself authorize flashing.
The full Nix target additionally builds AOSP's host `checkvintf` and verifies
the generated framework metadata against the exact `.3001` vendor/odm VINTF
files for the live `dsds` hardware SKU.

With the phone still running the exact rooted `.3001` baseline, combine that
audit with the live slot-0 layout and the scoped rollback set:

```bash
nix run .#preflight-lineage-userspace -- ./result ./result-stock-restore
```

This preflight is read-only. It verifies the complete image/AVB bundle, every
rollback hash, the active slot and the preserved OPlus allocation; it does not
reboot, flash, erase or wipe the phone.

Only after that command passes and a rollback test is ready, the bounded
hardware helper can install or restore the same directories:

```bash
nix run .#lineage-userspace -- install ./result ./result-stock-restore
nix run .#lineage-userspace -- \
  install ./result ./result-stock-restore --stay-bootloader
nix run .#lineage-userspace -- restore ./result-stock-restore
```

The install action leaves exact live `vendor`, `odm` and `dtbo` in place and
writes only `system`, `system_ext`, `product`, `boot_a` and the three slot-A
AVB metadata images. The restore action verifies every stock hash again before
writing the five standard logical images plus stock slot-A boot/AVB metadata.
Neither action can name or write an OPlus logical partition. The optional
install-only `--stay-bootloader` mode avoids a first system boot so an audited
private boot pair can be installed before entering recovery for add-ons.

For a private headless bring-up build, `KAREN_DEBUG_ADB_KEYS` may point to
exactly one Android public key on the selected build host, including the
optional `s-tau` workflow. This keeps `ro.adb.secure=1`; it does not enable
open or root ADB. Images containing that key are rejected by the normal audit
and must remain outside Git:

```bash
nix run .#audit-lineage-images -- \
  --allow-embedded-adb-key ./private-keybound-result
```

If the matching base userspace is already installed and the phone has been
put manually in ordinary bootloader-fastboot, the bounded helper can write or
restore only its audited `boot_a`/`vbmeta_a` pair:

```bash
nix run .#lineage-keybound-adb -- \
  install ./private-keybound-result ./base-result
nix run .#lineage-keybound-adb -- restore ./base-result
```

The install path also requires the embedded public key to match the normal
user's local `~/.android/adbkey` private key and requires every non-boot-pair
image to be byte-identical to the base bundle. This is a bring-up fallback,
not a release configuration.

If an enforcing boot returns to recovery before Android ADB starts, a private
diagnostic rebuild may additionally set `KAREN_DEBUG_PERMISSIVE=true`. Both
the image audit and the boot-pair helper reject that command line unless
`--allow-permissive-selinux` is explicit. Use it only to isolate policy
failures, collect general denials and return immediately to an enforcing
build; it is never a release or daily-use configuration.

The first full-system hardware boot initially returned to recovery because
stock userdata carried an incompatible encryption policy on `/data/app`.
Lineage Recovery identified that exact policy failure and its built-in factory
reset resolved it. The same candidate now completes an encrypted, SELinux
enforcing Lineage 21 boot on slot A. Display/touch, camera, audio, internet and
the passive framework/core-service checks have passed; the remaining manual
hardware matrix is tracked in [the follow-up](docs/follow-up.md).

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

Audit the running Lineage system without collecting device identifiers:

```bash
nix run .#audit-lineage-runtime
```

Install the separately pinned Aurora Store directly, without first installing
F-Droid and without disabling any Android package:

```bash
nix run .#install-aurora
```

Realize the optional Android 14 arm64 Google-app add-on without installing it:

```bash
nix build .#mindthegapps-14-arm64
```

The Lineage-owned `system`, `system_ext` and `product` images use ext4 with
explicit add-on headroom; exact stock `vendor` and `odm` remain EROFS. This
allows the standard Lineage Recovery sideload route instead of baking Google
apps into the vanilla ROM. LineageOS requires a factory reset when adding
GApps to a system that has already booted without them. The vanilla, GApps,
minimal-root, full-root and owner-opinionated flows therefore remain explicit
layers rather than one implicit ROM definition.

Create an identifier-filtered, rootless device snapshot:

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
nix run .#extract-stock -- --profile restore
nix run .#extract-stock -- --profile firmware
nix run .#extract-stock -- --profile stock
```

The extractor verifies the full OTA and every resulting image against
[`firmware/partitions-3001.json`](firmware/partitions-3001.json), then
rootlessly expands all EROFS blob partitions when requested. `restore`
contains only the exact boot/AVB and five standard logical images used by the
Lineage rollback procedure; build the pinned set with
`nix build .#stock-restore-3001`. `stock` contains all 34 images present in the
payload; it is not by itself a BROM restore package because the OTA has no
GPT, Download Agent, authentication material or `vendor_boot`. For a clean
Nix-store copy of the same official OPlus CDN object, use:

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

The working Lineage 21 port has separate image-directory-based equivalents:

```bash
nix run .#lineage-root -- /path/to/lineage-images --persist
nix run .#lineage-root-full -- /path/to/lineage-images --persist
nix run .#lineage-unroot -- /path/to/lineage-images --persist
```

Add `--allow-embedded-adb-key` only for a private key-bound bring-up bundle.
Minimal Lineage root does not enable Zygisk or install concealment modules, so
a clean baseline keeps runtime debugging representative. The full profile
deliberately enables the same pinned concealment stack as `stock-root-full`.
Unroot restores the exact audited Lineage `vbmeta_a`/`boot_a` pair. See
[LineageOS root and unroot](docs/lineage-root.md) for the safety gates and the
bootloop recovery form.

The default firmware directory is
`$XDG_CACHE_HOME/nord2t-recovery`, falling back to
`$HOME/.cache/nord2t-recovery`. Firmware, APKs, dumps and snapshots are ignored
by Git.

## Documentation

- [Device inventory](docs/device.md)
- [OS choice](docs/os-options.md)
- [Update and recovery](docs/recovery.md)
- [Stock root and unroot](docs/stock-root.md)
- [LineageOS root and unroot](docs/lineage-root.md)
- [Hardbrick recovery](docs/hardbrick-recovery.md)
- [TWRP image audit](docs/twrp-audit.md)
- [LineageOS port assessment](docs/lineage-port.md)

Run all repository checks with:

```bash
nix flake check --all-systems
```

Bootloader unlocking erases user data and gives up the stock Verified Boot
trust state. Root helpers deliberately constrain their boot-chain writes and
retain exact audited unroot routes. The successful hardware boot does not turn
this private LineageOS bring-up bundle into a supported flashable release.
