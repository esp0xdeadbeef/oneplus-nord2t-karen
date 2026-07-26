<!-- SPDX-License-Identifier: MIT -->

# OnePlus Nord 2T 5G (`CPH2399` / `karen`)

Reproducible stock recovery and unofficial LineageOS bring-up tooling for the
European OnePlus Nord 2T 5G.

A full Mobile NixOS host with a containerized LineageOS hardware-compatibility
layer is planned in this same device-integration repository. Bring-up starts
with headless kexec tests from rooted LineageOS through Magisk before any
persistent NixOS install. Its scope, repository boundary, staged bring-up and
hardware safety gates are documented in the
[Mobile NixOS feature plan](docs/feature-nixos.md).
The initial build-only device metadata and structure-aware DTB patch workspace
live under [`nixos/`](nixos/README.md); they perform no hardware writes.
The root flake is intentionally only wiring; the package, kernel, app and
check boundaries are documented in the
[Nix expression layout](nix/README.md).
The exact public firmware inventory, DTB/X13s comparison and remaining native
driver gates are tracked separately in the
[NixOS blocker matrix](docs/nixos-blockers.md).
The opinionated MT6893 control-kernel configuration MUST set
`CONFIG_KEXEC=y`: the pinned stock `.3001` kernel has classic kexec disabled,
and the Magisk kexec module supplies only the userspace loader. Enabling the
flag is a prerequisite for the staged kexec tests, not proof that MediaTek
driver shutdown or the second-kernel handoff will succeed.

This repository does not commit flashable images. As of 2026-07-25, `CPH2399`
is not officially supported by GrapheneOS or LineageOS. The local port now
boots LineageOS 21 on the test phone, but remains a private bring-up build
rather than a supported release. The exact official OxygenOS
`CPH2399_14.0.0.3001(EX01)` inputs and bounded rollback paths remain pinned.

For the current resumable checkpoint, active owner paths, mandatory next gates
and rollback order, see [`docs/follow-up.md`](docs/follow-up.md). The owner's
optional compilation offload is described separately in the
[remote-build-host guide](docs/remote-builder.md).

The scripts refuse to operate on a device unless ADB reports both:

- model `CPH2399`;
- product device `OP557AL1`.

Do not flash builds for `oscaro`, `avicii` or `denniz`. Those are different
phones.

## Current state

The test phone completed a full Lineage-to-stock rollback on slot A. Exact
OxygenOS `CPH2399_14.0.0.3001(EX01)` booted encrypted and enforcing after a
stock factory reset, then booted with green Verified Boot, locked vbmeta and
no root after a successful bootloader relock and its mandatory wipe. This
proves the complete stock/recovery/lock side of the roundtrip.

The bootloader has since been deliberately unlocked again, performing the
expected second wipe. The complete ext4 Lineage `system`, `system_ext` and
`product` images are installed on slot A alongside the exact pinned stock
`vendor` and `odm`; all ten existing OPlus logical partitions were preserved.
Lineage Recovery completed its factory reset, the pinned Android 14 arm64
MindTheGapps add-on completed with status 0, and the phone now boots encrypted,
SELinux-enforcing Lineage 21 with working display, touch, camera, audio and
internet.

The first bounded install used a temporary audited permissive recovery to
isolate one fastbootd SELinux-label failure, then restored the enforcing
AVB/boot pair before Android booted. The source policy now labels the
tmpfs-created extended `super` node through an exact `genfscon` rule. The
compiled-policy audit passes and a subsequent enforcing Lineage fastbootd
hardware test exposed `super`, all five standard mappings and all ten
preserved OPlus mappings without stock-recovery staging.

The current private test boot also runs pinned Magisk 30.7 with Zygisk,
Vector, Shamiko, Systemless Hosts and the separately installed kexec module.
Hide My Applist remains experimental: enabling its `system` scope with Vector
2.0 caused Launcher/SystemUI to stall because its native hook could not be
mapped. Removing that scope restored normal operation. The repository's
future opinionated helper must keep that setting fail-closed until the
framework compatibility issue is fixed and a boot health check passes.

The earlier Lineage boot exercised display, touch, camera, audio and internet
successfully. Its passive runtime audit reported the expected framework,
binder services, core processes, input devices and DRM node. Calls, SMS,
mobile data, Wi-Fi association, Bluetooth pairing, NFC, GPS/navigation,
suspend/resume, charging, push notifications and banking-app behavior still
need explicit real-world checks after the next audited Lineage install.

A standard testkey-signed Lineage A/B installation ZIP has also been built
and cryptographically verified, but must not be flashed yet. Its full payload
contains only the five standard logical partitions, while the live device has
ten additional required OPlus partitions only in `main_a`. AOSP update-engine
deletes target-slot partitions omitted by a non-partial payload. The
publishable installer must therefore model that layout or use an audited
partial-update strategy before the ZIP becomes the recommended path.

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

The optional full rooted stack adds four more locked upstream inputs:
Vector 2.0, Shamiko 1.2.5, Hide My Applist 3.8 and AdAway 6.1.4. Vector and
AdAway are built from exact Git revisions with generated Nix Gradle dependency
locks. AdAway stays unsigned in the Nix store and is signed on the trusted
phone host with the split SOPS owner identity immediately before installation.
Its upstream-required Gradle 8.9 distribution is also fixed by version and Nix
content hash; the current nixpkgs `gradle_8` is newer and is not substituted.
Shamiko and Hide My Applist remain exact official release inputs for the
licensing/source-availability reasons documented below. No helper resolves a
“latest” URL at runtime.

`npins` would also be able to lock these repositories, but this flake does not
maintain a second lock format: every non-flake Git input carries an explicit
`rev`, while `flake.lock` records that revision and its NAR hash. Maven
artifacts which Git cannot cover are fixed separately in `gradle/*-deps.json`.
Upgrading a component therefore changes its source revision, dependency lock
and audited output together.

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
workflow, only its public half may be copied to the build host.
`KAREN_DEBUG_ADB_PUBLIC_KEY_FILE` points the impure flake evaluation at that
file; the flake validates it before supplying Android's internal
`KAREN_DEBUG_ADB_KEYS` value. Vanilla builds require neither file. Other
owners get their own isolated `secrets/HOST-USER-adb-host-key.age` by running
the same command on their phone/build host.

## Owner Android signing

The opinionated root-full profile needs a stable Vector manager identity so an
update cannot silently change the certificate trusted by Vector's daemon.
Create or verify that identity from `l-esp` or `l-portal`:

```bash
nix run .#vector-signing-key-generator
```

The command creates two committed, SOPS-encrypted JSON documents. The shared
document contains only the public X.509 certificate, its digest and the key
alias; `l-esp`, `l-portal` and the optional remote builder can decrypt it.
The private document contains the JKS and the four Android signing attributes
`androidStoreFile`, `androidStorePassword`, `androidKeyAlias` and
`androidKeyPassword`; only `l-esp` and `l-portal` can decrypt it. Passwords
are generated randomly and are passed to `keytool` and `apksigner` through
mode-0600 files, never as Gradle properties or command-line values.

This split keeps compilation offload possible without copying the private key
to the builder:

```bash
# On the compilation host: embeds only the public certificate.
nix run .#vector-owner-build-intermediate -- \
  --output ./Vector-owner-intermediate.zip

# After returning that artifact to l-esp or l-portal: applies the private key.
nix run .#vector-owner-sign -- \
  ./Vector-owner-intermediate.zip \
  --output ./Vector-owner-signed.zip
```

The final signing helper verifies that both encrypted documents describe the
same certificate, signs both embedded APKs, checks their signer digest,
refreshes the module checksums and creates a new ZIP. Generic users may keep
using `vector-module`; neither SOPS identity nor a remote builder is required
for the non-owner build.

The same owner identity signs the source-built AdAway APK. Both root-full
helpers invoke `owner-sign-apk` automatically after all device checks and
explicit confirmation. The unsigned APK is compiled by Nix; only the final
signing step decrypts the private document, outside the Nix store. Android
cannot update an already installed official AdAway with this different owner
certificate. In that case the helper stops without deleting app data; removal
of the old package must be an explicit owner action before rerunning it.

Both full-root routes use that reproducible generic module by default. The
owner-signed output can be selected without putting it in Git:

```bash
vector_zip=/private/path/Vector-owner-signed.zip
vector_hash="$(sha256sum "$vector_zip" | cut -d' ' -f1)"
nix run .#lineage-root-full -- /path/to/lineage-images \
  --persist \
  --vector-module "$vector_zip" \
  --vector-module-sha256 "$vector_hash"
```

`--vector-module` and its explicit hash are accepted only by the two
`root-full` helpers; minimal-root and unroot paths cannot install the
concealment stack.

The repository then adds the local `karen` tree without committing proprietary
or stock-derived binaries. There are three useful build paths:

```bash
# Derive the stock kernel, DTB and DTBO and export the device tree.
nix run .#karen-device-tree

# Realize the locked Lineage source graph and export boot.img.
nix run .#karen-bootimage

# Build and export the full bring-up image set with verified stock vendor/odm.
nix run .#karen-full-images

# Build and export the current official-source control kernel.
nix run .#karen-source-kernel-bootimage

# Use the persistent Robotnix compiler cache for repeated kernel ABI probes,
# then for the complete source-kernel bundle.
nix run .#karen-source-kernel-bootimage-cached
nix run .#karen-source-kernel-full-images-cached

# Check the kernel-only result against all exact pinned vendor-module imports
# before spending time on a complete Android image.
nix run .#audit-kernel-module-abi -- \
  ./result-karen-source-kernel-bootimage-cached \
  /private/path/to/vendor.img

# Compare a candidate with the pinned stock boot image and inspect its ramdisk.
nix run .#audit-boot -- ./result-karen-bootimage/boot.img

# Enter the FHS environment for faster, mutable Android-tree iteration.
nix run .#android-fhs
```

Each build app accepts an optional output directory and otherwise uses the
shown `result-karen-*` name in the current directory. It refuses to overwrite
an existing path. Nix store paths remain internal dependencies and never need
to be copied from logs or hardcoded in a command.

The normal image targets remain host-independent and use only Nix's immutable
store cache. The explicit `-cached` full-image variants additionally use
Robotnix's persistent `/var/cache/ccache`; they fail early unless the host has
granted that path to Nix build sandboxes with `root:nixbld` group-write
access. This mutable compiler cache does not enter the result or store, does
not contain device keys, and does not replace the persistent `out` directory
used by the optional interactive workflow. The exact 400 GB owner-host setup
and its expiry warning are documented in the
[remote-builder guide](docs/remote-builder.md).

`android-fhs` is a filesystem-layout compatibility shim, not an unpinned
package source. Its host tools are selected from the exact nixpkgs revision in
`flake.lock`; the Android/Lineage sources and their prebuilts are selected from
robotnix's locked source graph. Robotnix also uses a pinned FHS environment
inside the reproducible `karen-*` derivations because modern Soong still
expects conventional loader, `/usr/lib{,32}` and default-shell paths. Removing
that namespace would require a broader Soong/robotnix host-layout port without
improving source or tool version pinning.

The first clean build of `karen-bootimage` must fetch and realize the complete
LineageOS/AOSP source graph. Those repositories become ordinary immutable Nix
store paths and are reused by later builds. A sufficiently large local machine
can run every target directly. The owner optionally uses a host over SSH
because `l-esp` ran out of memory during full Android builds; no host exception
or machine-specific builder configuration is part of this repository. See the
[optional remote-build-host workflow](docs/remote-builder.md).

The source-kernel target pins OnePlus's corresponding MT6893 kernel and
MediaTek module repositories exactly. The combined source layout and control
kernel now compile; installable full-image builds additionally require the
source kernel to retain the exact stock module release and public trust anchor.
Those ABI and signature gates are documented in the
[LineageOS port assessment](docs/lineage-port.md).

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

With the phone running either the exact rooted `.3001` baseline or the audited
private Lineage Recovery, combine that audit with the live slot-0 layout and
the scoped rollback set:

```bash
nix run .#preflight-lineage-userspace -- ./result ./result-stock-restore
```

For a private key-bound bundle, pass `--allow-embedded-adb-key` explicitly to
both this preflight and the later install action. Neither helper infers that
exception from the image.

This preflight is read-only. It verifies the complete image/AVB bundle, every
rollback hash, the active slot and the preserved OPlus allocation; it does not
reboot, flash, erase or wipe the phone. In recovery it copies only the first
4 MiB of the generic `super` block device for host-side metadata parsing. It
rejects any COW snapshot partition by default. `--cleanup-stale-cow` makes the
install helper accept only the exact nine-partition stale set recorded for
this stock baseline, then requires stock fastbootd status `none` before
deleting it. The helper never requests a snapshot cancel or merge.

Only after that command passes and a rollback test is ready, the bounded
hardware helper can install or restore the same directories:

```bash
nix run .#lineage-userspace -- install ./result ./result-stock-restore
nix run .#lineage-userspace -- \
  install ./result ./result-stock-restore --stay-bootloader
nix run .#lineage-userspace -- \
  install ./result ./result-stock-restore \
  --cleanup-stale-cow --stay-bootloader
nix run .#lineage-userspace -- restore ./result-stock-restore
```

The install action first stages the exact stock boot/AVB chain so the tested
stock fastbootd exposes explicit slot-A mappings. It then leaves exact live
`vendor`, `odm` and `dtbo` in place and writes only `system`, `system_ext`,
`product`, `boot_a` and the three slot-A AVB metadata images. The restore
action verifies every stock hash again before writing the five standard
logical images plus stock slot-A boot/AVB metadata. Neither action can name or
write an OPlus logical partition. The optional install-only
`--stay-bootloader` mode avoids a first system boot so an audited private boot
pair can be installed before entering recovery for add-ons.

For a private headless bring-up build,
`KAREN_DEBUG_ADB_PUBLIC_KEY_FILE` may point to exactly one Android public key
on the selected build host, including the optional remote-build workflow.
The flake maps it to Android's internal `KAREN_DEBUG_ADB_KEYS` value. This
keeps `ro.adb.secure=1`; it does not enable open or root ADB. Images containing
that key are rejected by the normal audit and must remain outside Git:

```bash
nix run .#audit-lineage-images -- \
  --allow-embedded-adb-key ./private-keybound-result
```

If the matching base userspace is already installed and the phone has been
put manually in ordinary bootloader-fastboot, the bounded helper can write or
restore only its audited `boot_a`/`vbmeta_a` pair:

```bash
nix run .#lineage-keybound-adb -- \
  install ./private-keybound-result ./base-result --stay-bootloader
nix run .#lineage-keybound-adb -- restore ./base-result
```

The install path also requires the embedded public key to match the normal
user's local `~/.android/adbkey` private key and requires every non-boot-pair
image to be byte-identical to the base bundle. It compares the cryptographic
ADB key token, not the disposable `user@host` comment. This is a bring-up
fallback, not a release configuration.
The install-only `--stay-bootloader` option permits the next boot to go
directly to Lineage Recovery for GApps or another supported add-on.

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

The pinned build completed successfully on the optional remote build host and
its resulting recovery-as-boot image passed the repository's structural audit. Its kernel
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
Both full routes also accept a locally owner-signed Vector ZIP only when its
explicit SHA-256 is supplied alongside it.
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
- [Mobile NixOS feature plan](docs/feature-nixos.md)
- [NixOS firmware, DTB and driver blockers](docs/nixos-blockers.md)
- [Nix expression layout](nix/README.md)

Run all repository checks with:

```bash
nix flake check --all-systems
```

Bootloader unlocking erases user data and gives up the stock Verified Boot
trust state. Root helpers deliberately constrain their boot-chain writes and
retain exact audited unroot routes. The successful hardware boot does not turn
this private LineageOS bring-up bundle into a supported flashable release.
