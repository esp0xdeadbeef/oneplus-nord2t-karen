<!-- SPDX-License-Identifier: MIT -->

# LineageOS port assessment

There is currently no installable LineageOS product in this repository. The
small tree under `lineage/device/oneplus/karen` is an experimental Lineage 21
recovery bring-up, not a ROM release. It deliberately starts with the exact
verified stock kernel and device trees so ramdisk, display and USB assumptions
can be tested independently. Set `KAREN_BUILD_SOURCE_KERNEL=true` only after
that baseline boots.

References to `s-tau` in this assessment record historical build provenance
and the repository owner's current RAM offload. The host is not a dependency;
the same commands may run locally or on another suitable machine. See the
[optional remote-build-host guide](remote-builder.md).

## Stock-derived build inputs

The bring-up currently needs three binaries from the matching OxygenOS build:
the stock kernel, DTB and `dtbo.img`. They are build inputs, not source code,
and must never be committed:

```text
lineage/device/oneplus/karen/prebuilt/kernel
lineage/device/oneplus/karen/prebuilt/dtbs/karen.dtb
lineage/device/oneplus/karen/prebuilt/dtbo.img
```

All three paths are covered by `.gitignore`. The repository contains neither
downloaded OTA files nor extracted stock binaries. Both supported preparation
routes derive the files from the `stock-firmware-3001` flake input, verify the
OTA and partition hashes from the manifests, and unpack the kernel and DTB from
the verified `boot.img`.

For a fully Nix-managed result, build the prepared device tree directly:

```sh
nix build .#karen-device-tree
```

The resulting tree is immutable in `/nix/store`; build scratch data stays in
the Nix sandbox. The experimental `.#karen-bootimage` target additionally uses
Robotnix's locked Lineage 21 source set, builds `bootimage` in a Nix derivation,
and writes only the resulting `boot.img` to the store:

```sh
nix build .#karen-bootimage
```

Robotnix's upstream Lineage lock includes TheMuppets vendor repositories for
all supported devices. The flake derives a filtered lock that removes those
unrelated proprietary repositories; it retains every AOSP and Lineage project
at the same pinned commit and content hash. Karen's matching stock inputs are
derived independently from the verified `.3001` OTA.

The pinned Lineage 21 `vendor/lineage` revision uses the newer Android 14
bootanimation makefile layout. Robotnix 21.0 otherwise selects its older patch,
so this repository explicitly selects Robotnix's own `-21` reproducibility
patch while retaining the other upstream Robotnix patches.

This target exists to make remote builds and source pinning testable during
bring-up. It does not make the unbooted image safe to flash.

### Full-system compatibility inputs

The full userspace target is separate from the deliberately insecure recovery
probe:

```sh
nix build .#stock-lineage-3001
nix build .#karen-full-images
```

The first derivation extracts only `vendor` and `odm` from the pinned full
OTA, verifies them against the partition manifest and expands only their
generic filesystem trees. On `s-tau` on 2026-07-25 it produced:

```text
OTA SHA-256:    4ca89d77ce64e09f1b061db69e5589be7ad60d2c0403b2e9217e47862352c41f
vendor bytes:   487354368
vendor SHA-256: 6f12d0c8eeb8399b194951c6ce8abbc14c789453b6620c04241e8d95887c222c
odm bytes:      1118810112
odm SHA-256:    df850835446ecbeee14bbbe1a157e0dfc3d8f6af2bcb7e14a7f01e99dfb82cf3
```

The full target builds Lineage `boot`, `system`, `system_ext` and `product`,
uses those exact stock `vendor` and `odm` images, and builds the associated
`vbmeta`, `vbmeta_system` and `vbmeta_vendor` images. It does not inherit
`WITH_ADB_INSECURE`. Its first-stage ramdisk uses the complete matching stock
mount table so vendor services can see the OPlus logical and hardware-data
mounts, while Lineage Recovery continues to use the deliberately reduced
`TARGET_RECOVERY_FSTAB` and cannot offer sensitive partitions as wipe targets.

The corrected full build completed 117,156 actions on `s-tau` in 1:10:10.
The first explicit VINTF audit rejected its framework metadata before any
phone write. Importing the exact optional device framework matrix from the
pinned stock `system` image resolved the MediaTek/OPlus declarations but
exposed two further stock-compatibility requirements. The vendor compatibility
matrix requires VNDK 31, so the full target now builds and installs the real
`com.android.vndk.v31` snapshot APEX. The live vendor manifest also exposes
`vendor.mediatek.hardware.camera.isphal@1.0::IISPModule/internal/0`, while
the OEM framework matrix lists only version 1.1; a small open device matrix
fragment truthfully declares the live 1.0 instance.

After those changes, host `checkvintf` accepted the generated framework
metadata with exact `.3001` vendor/odm metadata and the live `dsds` SKU.
Candidate 2 then passed the complete image audit: exact stock kernel/DTB,
authenticated ADB, all AVB chains, exact stock vendor/odm and a
2,802,786,304-byte standard-image total below the preserved
8,816,586,752-byte ceiling. This is host-side permission to run the live
read-only preflight, not evidence of a hardware boot.

The live preflight subsequently confirmed the exact slot-A `.3001` baseline,
all 15 logical partitions, the untouched OPlus allocation and the complete
local rollback set. The first bounded install reached fastbootd and resized
`system_a`, but fastbootd rejected the first Lineage sparse data chunk before
any chunk reported success. Keeping the same USB mode, the restore action
successfully wrote the exact stock `system`, `system_ext`, `product`, `vendor`
and `odm` images, then exact slot-A boot and AVB metadata, and rebooted. It did
not name or write any OPlus partition or `dtbo`.

Because the same host fastboot and raw-image conversion completed every stock
transfer immediately afterward, the failure is consistent with a transient
fastbootd/USB readiness problem rather than a rejected image format, though
that cause is not yet proven. The helper now adds a post-enumeration settle
period and one bounded full-image retry per allowed partition. A second
Lineage attempt still requires a fresh stock property/layout preflight and
post-boot hardware evidence.

An earlier full-userspace derivation completed all 164,803 Android build tasks
on `s-tau` in 1 hour 19 minutes. Its `boot`, `system`, `system_ext`, `product`
and top-level `vbmeta` images were structurally valid, and the boot audit
confirmed authenticated ADB plus the exact stock kernel and DTB. The result
was rejected before hardware use: it generated a 16,510,976-byte `vendor`
image and a 454,656-byte `odm` image instead of the 487,354,368-byte and
1,118,810,112-byte stock images, and its install output omitted
`vbmeta_system` and `vbmeta_vendor`. The current target therefore treats both
stock images as explicit prebuilts and requests every chained AVB image. The
corrected second candidate subsequently passed the complete image, AVB and
VINTF audits described below.

None of those inputs contains device-unique data: they come from the public
full OTA. Live `nvdata`, `nvram`, calibration, persistent and radio data stay
on the phone and outside both the build and Git. A completed build still needs
image, VINTF, AVB, size and restore audits before any full-system flash.

Approved read-only `lpdump --slot 0 --json` output from the running `.3001`
system confirmed virtual A/B metadata version 10.2, a 12,348,030,976-byte
`super` device and a 12,343,836,672-byte `main` group. The latter is exactly
`super` minus the required 4 MiB overhead and is now the build limit. The live
group contains the five standard partitions plus ten OPlus partitions:
`my_engineering`, `my_product`, `my_stock`, `my_heytap`, `my_company`,
`my_carrier`, `my_region`, `my_preload`, `my_bigball` and `my_manifest`.
Those ten OPlus allocations occupy 3,527,249,920 bytes in total. Leaving them
byte-for-byte in place gives the five standard logical images a combined
8,816,586,752-byte ceiling. The current stock standard allocations use
3,549,384,704 bytes and the complete group uses 7,076,634,624 bytes. A
hardware-test helper must recompute those figures from a fresh read-only
`lpdump` immediately before writing and refuse the test if the names, group or
available standard-image budget have changed.

The same layout can now be checked from the audited private Lineage Recovery
without adding `lpdump` to its ramdisk. The host copies only the first 4 MiB of
the generic `super` block device, parses its slot-0 metadata with the pinned
host tool and normalizes the `_a` names. It never reads a logical filesystem,
an OPlus partition or device-unique storage.

That recovery check currently also sees nine `-cow` partitions consuming the
otherwise free super extents. A complete rootless stock boot did not remove
them. Bootloader-fastboot returned no usable status, but exact stock fastbootd
reported `snapshot-update-status=none` and exposed all nine COW entries with
the sizes from the raw metadata. The default preflight therefore still
rejects the current layout.

The install-only `--cleanup-stale-cow` path accepts only that exact set. After
staging the stock boot chain it requires fastbootd to report `none`, verifies
all nine logical names and sizes again, and deletes only those temporary
partitions. It does not silently omit them and neither helper issues
`snapshot-update cancel` or merge. Android's documented full-flash flow uses
cancel only when the target reports `merging` or `snapshotted`; that is not
the state observed here. See the
[AOSP Virtual A/B fastboot guidance](https://source.android.com/docs/core/ota/virtual_ab/implement#fastboot-tooling-changes).

Android's unmodified dynamic-partition build configuration accepts the
standard partition set, not those OPlus names. The initial test plan must
therefore leave every live OPlus logical partition in place. Do not build or
install an OTA or generated `super.img` until the target-files metadata can
round-trip all 15 partition names without deleting, shrinking or moving the
OPlus partitions.

The other super metadata slots do not provide a ready-made inactive-system
test target. Slot 0 is enabled and contains the populated `main` group above.
Slot 1 is enabled but contains only 15 size-less placeholders and no group;
slot 2 is unavailable. This is consistent with a virtual A/B device after its
snapshot update has completed, not with two independently populated physical
sets of logical partitions. The proven `boot_b` recovery test cannot simply be
extended to `system_b`.

A full userspace hardware test must therefore enter fastbootd, update only the
audited standard logical images, and have all exact `.3001` standard images
available for a reverse fastbootd write. That operation is destructive to the
current stock userspace even though the ten OPlus logical images remain
untouched. It must not start until the host-side restore procedure has
validated product, group limit, image hashes, required free space and return
to stock recovery/boot.

The required mode transition was exercised non-destructively on 2026-07-25.
`fastboot reboot fastboot` moved bootloader-fastboot into fastbootd and
`fastboot reboot bootloader` returned to bootloader-fastboot; `is-userspace`
reported `yes` and `no` respectively. Host helpers must account for
`fastboot devices` labelling those modes `fastbootd` and `fastboot` rather
than treating both labels as ordinary bootloader-fastboot.

Approved root was used only to hash the five generic live read-only logical
block devices. The running slot-A `system`, `system_ext`, `product`, `vendor`
and `odm` hashes each match the corresponding `.3001` OTA image exactly. No
radio, calibration, persistent or OPlus data partition was read. This proves
that the pinned OTA contains byte-exact reverse images for every standard
logical partition a first full-system test will modify; it does not yet prove
that fastbootd can resize and restore them safely.

### Verified build and structural audit

The pinned derivation completed successfully on `s-tau` on 2026-07-24. After
the source graph was present in the Nix store, Android built all 10,263
required targets and produced:

```text
image size:   67108864 bytes
image SHA-256: 83f84198841415fd4934ce5fc283e64922562d1cc95e40acfb37c909de8607e2
kernel SHA-256: 917716ae774cc32f71d1b7f7962e472ece9e5f82c1676e4362ac90b7219dac10
DTB SHA-256: 3f556b701b84247e529d4c05a46c7e45c9e29cffd4aca2c18822290de8d603c6
```

Reproduce the comparison with:

```sh
nix build .#karen-bootimage
nix run .#audit-boot -- --allow-insecure-adb ./result/boot.img
```

The audit verifies:

- the exact 64 MiB boot partition size and Android boot header v2;
- stock-matching base, page size and offsets, plus the recovery-only init fatal
  reboot target used by Lineage's comparable MediaTek recovery-as-boot trees;
- a byte-identical `.3001` stock kernel and DTB;
- a valid AVB hash footer for partition `boot`;
- Lineage Recovery, `adbd`, fastbootd, init and SELinux policy in the ramdisk;
- the current F2FS metadata-encryption parameters and logical EROFS mappings;
- a first-stage fstab and virtual A/B `snapuserd` in the boot ramdisk;
- absence of device-unique and security partitions from the recovery fstab.

The pinned recovery-only Robotnix derivation sets Lineage's own
`WITH_ADB_INSECURE=true` product-make switch so a wiped device can provide a
headless diagnostic shell. This must never be set for an installable system
build. The audit rejects `ro.adb.secure=0` by default and accepts it only with
the explicit `--allow-insecure-adb` bring-up flag.

The test image has an unsigned AVB footer (`Algorithm: NONE`) and test keys.
Its header reports the pinned Lineage source patch level of 2026-04, while
stock reports 2026-06. It is therefore correctly classified as an experimental
unlock-only image, not as a signed release or a replacement security baseline.
Structural success does not prove display, touch, USB or block-device behavior
on hardware.

### First hardware boot probe

The bootloader was unlocked through bootloader-fastboot on 2026-07-24. It
enumerated only after moving the cable from the Lenovo dock to a direct laptop
USB port. The first audited image, SHA-256
`83f84198841415fd4934ce5fc283e64922562d1cc95e40acfb37c909de8607e2`,
was sent with `fastboot boot`; all 64 MiB transferred successfully. The phone
then disconnected before fastboot received the final boot status. That
transport error alone does not prove boot failure.

The host subsequently saw the MediaTek Android ADB interface
(`0e8d:201c`) reconnect repeatedly, and the phone eventually returned to stock
OxygenOS on slot `a`. Stock reported `ro.boot.bootreason=lk_crash`,
`ro.boot.verifiedbootstate=orange` and an unlocked bootloader. The original
image required authenticated ADB, while the unlock wipe had removed the
authorized device-side key, so it did not yield a diagnostic recovery shell.
The next probe therefore changes only the recovery ADB authentication setting
through the explicitly scoped Robotnix environment described above.

The insecure-ADB recovery probe behaved the same way and also returned to
stock. A stronger control then used the exact `.3001` stock boot image patched
with pinned Magisk `30.7`: temporary `fastboot boot` again returned with
`lk_crash` and no Magisk process, while writing the byte-identical control to
active `boot_a` booted normally and provided approved `uid=0(root)`. This
proves that transport completion is not a hardware-boot result on this loader.
Further recovery testing must use a slotted write with the pinned stock
restore image immediately available.

### Virtual A/B ramdisk correction

The first two candidates predated the live root inspection and did not inherit
Android's `virtual_ab_ota.mk`. Their recovery ramdisk consequently contained
only `system/etc/recovery.fstab`, not stock's
`first_stage_ramdisk/fstab.mt6893`, and had no first-stage `snapuserd`.

The closest official Lineage MediaTek precedent,
`android_device_xiaomi_rosemary`, uses the same header-v2,
recovery-as-boot, 64-MiB boot and 8-MiB DTBO layout. It enables the A/B updater,
inherits `virtual_ab_ota.mk` and adds
`androidboot.init_fatal_reboot_target=recovery`. Karen now follows only those
layout decisions while retaining its own verified offsets, fstab, stock
kernel, DTB and DTBO. Its A/B update list explicitly includes the five
Lineage-built logical partitions and the matching boot/AVB metadata.

### Successful inactive-slot recovery boot

The corrected build completed on `s-tau` and produced a 64 MiB `boot.img` with
SHA-256
`76d44168975a309785a7a60e059b9c1ae52248631a311ff315bb9c4eddac3ad2`.
Its stock kernel and DTB hashes remained unchanged. The structural audit
confirmed header v2, the recovery-only init fatal target, first-stage
`fstab.mt6893`, ramdisk `snapuserd`, Lineage Recovery and the deliberately
insecure bring-up ADB configuration. Its AVB footer uses algorithm `NONE` and
it remains test-keyed and unsuitable for release.

Because temporary `fastboot boot` had already been disproved by both stock and
Magisk controls, this candidate was written only to inactive `boot_b` after
the original contents of that slot were saved and hashed. Selecting slot `b`
then booted the recovery on the phone:

- the owner confirmed the Lineage Recovery UI on the display;
- recovery ADB enumerated over the direct laptop USB port;
- `ro.boot.slot_suffix` reported `_b` and `ro.bootmode` reported `recovery`;
- recovery `adbd` supplied the expected `uid=0(root)` diagnostic shell;
- first-stage fstab, `snapuserd`, DRM, framebuffer and input devices were
  present.

This is the first hardware execution proof for the port. It validates the
stock kernel/DTB plus Lineage ramdisk baseline, display and recovery USB ADB.
It does not yet validate touch, encrypted data access, sideload, recovery
fastbootd, radio or any complete Lineage system image.

The phone was returned to stock without navigating the recovery UI:

```sh
adb shell reboot bootloader
fastboot getvar is-userspace
fastboot getvar product
fastboot getvar hw-revision
fastboot getvar unlocked
fastboot set_active a
fastboot flash boot_b /private/verified/original-boot_b.img
fastboot reboot
```

The live restored `boot_b` hash matched its pre-test backup exactly. OxygenOS
`.3001` booted from slot `a`, SELinux remained enforcing, and the existing
Magisk-patched stock `boot_a` still provided the approved root shell. Runtime
logs are retained privately outside Git because host captures can contain
device identifiers.

### First full-userspace write

The VINTF-corrected second candidate passed the complete host audit and the
fresh live-layout preflight on 2026-07-25. A first bounded install stopped on
the first sparse `system_a` transfer with no Lineage data chunk reported as
written. The exact stock rollback then successfully rewrote all five standard
logical images and the slot-A boot/AVB chain without touching `dtbo`, vendor
extensions or an OPlus logical partition.

After adding a fastbootd settle delay and one bounded retry per allowlisted
partition, the same audited candidate passed the live stock preflight again.
The second install successfully resized and wrote `system_a`,
`system_ext_a` and `product_a`, then wrote `vbmeta_system_a`,
`vbmeta_vendor_a`, `vbmeta_a` and `boot_a` in bootloader-fastboot. Exact stock
`vendor`, `odm`, `dtbo` and all ten OPlus logical partitions remained in
place.

A later ext4 install exposed a second transport failure: the complete
four-chunk `system_a` write succeeded, but stock fastbootd rejected the first
default-size `system_ext_a` sparse chunk. The owner manually returned the
phone to ordinary bootloader-fastboot with `Volume Down + Power`; the helper
did not perform that transition. The default host chunks were roughly
256 MiB. Logical flashes now use `fastboot -S 64M`, verify fastbootd again
immediately before every write and emit a non-identifying mode attestation.
Boot and AVB writes remain ordinary bootloader-fastboot operations.

The first observable system attempt initialized the Lineage framework,
mounted encrypted F2FS userdata and then performed an orderly reboot into
recovery. The recovery command reason was
`set_policy_failed:/data/app`: the retained stock userdata encryption policy
was incompatible with the new framework. A private permissive test followed
exactly the same path, excluding SELinux enforcement as the trigger.

Because userdata was backed up and a wipe was explicitly authorized, Lineage
Recovery performed its built-in factory reset. The next system boot completed.
The temporary permissive pair was then replaced by the already audited
key-bound enforcing pair; only `vbmeta_a` and `boot_a` were rewritten.
Lineage subsequently reached `sys.boot_completed=1` with file-based
encryption, SELinux enforcing, authenticated shell ADB, slot A active and the
expected unlocked/orange boot state. All passive framework service and core
process checks passed.

The enforcing runtime later exposed a separate userspace regression: Jelly
reproducibly died after its WebView 147 renderer trapped twice on `fast.com`.
Both renderer failures had the same native stack and occurred after roughly
46 seconds; memory pressure did not kill either process. Installing upstream
Lineage's same-certificate arm64 WebView `150.0.7871.63` as a reversible
package update kept the same page and renderer alive. The build now pins that
exact LFS-backed upstream revision independently of Robotnix's older generated
source lock. A rebuilt image must repeat the test before this becomes a
closed runtime gate.

The owner confirmed display/touch, camera, audio and internet operation.
GNSS and the remainder of the manual parity matrix are still pending. No
device identifier, authorization key, radio data or calibration data is
recorded in this repository.

### Recovery add-on compatibility

The first optional MindTheGapps sideload failed before copying any file:
recovery could not mount the Lineage-built EROFS `system` image read-write.
Karen now builds only the Lineage-owned `system`, `system_ext` and `product`
images as sparse ext4 with explicit free space. The public-OTA-derived
`vendor` and `odm` images remain byte-exact EROFS prebuilts.

The ext4 candidate passed VINTF and the complete image audit on `s-tau`.
The auditor converts each sparse image to its expanded form, verifies the ext4
superblock and required free blocks, and applies the live standard-image
ceiling to expanded sizes rather than misleading sparse-file sizes. The five
expanded standard images need 4,935,397,376 bytes, safely below the
8,816,586,752-byte limit that preserves every OPlus logical partition.

This keeps the vanilla ROM independent of Google apps. The intended optional
flow remains Lineage Recovery sideload before the first system boot, rather
than modifying the build graph to include GApps.

The first slot-A ext4 recovery test also made the formerly intermittent black
recovery screen reproducible. DRM reported a connected and enabled DSI panel,
and the recovery log showed successful framebuffer allocation. The kernel
trace showed Lineage Recovery applying OLED brightness before its opt-in
init-time blank/unblank cycle, then power-cycling the panel without reapplying
that brightness. Rewriting the existing `lcd-backlight` value restored the UI
immediately. Karen therefore no longer sets
`TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT`; the upstream default is the
correct behavior for this panel.

The boot-image audit now checks the final ramdisk for that property. It
rejected a stale incremental image even though the source flag had already
been removed, exposing an unchanged Kati recipe in the persistent checkout.
After forcing product-config regeneration, the rebuilt boot/vbmeta pair
passed the full image and VINTF audits. A hardware recovery boot then showed
one brightness application and no following panel disable/unprepare cycle,
without using the live brightness workaround.

The stock bootloader has one fastbootd-specific A/B defect: ordinary recovery
receives slot suffix `_a`, but a `boot-fastboot` recovery does not. Without
the suffix, Android's boot-control path cannot map any logical partition.
Because this bring-up intentionally supports only the populated slot A, the
boot command line supplies `androidboot.slot_suffix=_a`. Remove that
workaround only after a future bootloader or boot-control implementation
correctly reports the active slot in fastbootd.

Hardware testing showed that the boot command line alone is not sufficient.
The corrected value is present in ordinary recovery, but fastbootd still
reports an empty `current-slot` and creates no `system` or `system_a` mapping.
The bounded restore helper consequently remains fail-closed before any logical
write while the fastbootd slot/mapping source is investigated.

An exact stock boot/recovery and AVB pre-stage subsequently supplied a working
fallback: stock fastbootd reported slot A and created `system_a`. It exposed
only the explicitly suffixed logical name, even though `current-slot` was
valid. The bounded helper therefore detects unsuffixed and `_a` mappings
independently of slot reporting instead of inferring one behavior from the
other. Install and restore now stage that exact public-OTA boot/AVB chain
before entering fastbootd, so a currently installed private recovery cannot
silently select the mapping-deficient Lineage fastbootd.

As a headless fallback, the product now accepts an opt-in
`KAREN_DEBUG_ADB_KEYS` path for one local Android public key while retaining
`ro.adb.secure=1`. The normal audit rejects such a boot image; an explicit
private bring-up audit validates that the file contains one Android RSA
public key. A `s-tau` incremental build produced a complete private bundle,
and a hybrid using only its changed boot/top-level-vbmeta pair with the
installed candidate's other seven images passed the complete AVB and stock
vendor/odm audit. These key-derived artifacts remain outside Git.

The matching fastboot-only helper requires ordinary bootloader-fastboot,
unlocked slot A, exact Karen bootloader identity, a byte-identical base for
every non-boot-pair image, and a local private key matching the embedded
public key. Its allowlist contains only `vbmeta_a` and `boot_a`, with a
corresponding base-pair restore action. The enforcing variant supplied the
first verified full Lineage boot, but remains a private diagnostic access
path rather than a release configuration.

Later hardware work separated two independent fastbootd problems. Adding
AOSP's recovery BootControl service and narrowly labelling the concrete
extended-devt misc node fixed slot reporting: fastbootd reports slot A, two
slots and the unlocked bootloader state. Logical mappings still fail because
the concrete `super` node is recreated with the `tmpfs` label even though its
by-name symlink and final recovery file contexts identify it as
`super_block_device`. A live root-recovery `restorecon` proves that rule, but
does not persist across the separate fastbootd boot. Relabel actions at the
recovery `fs`, `boot` and fastboot USB triggers did not change the hardware
result.

A temporary audited permissive recovery made the same fastbootd expose
`super`, all five standard logical mappings and all ten preserved OPlus
mappings. That isolated the remaining fault to SELinux labelling. The host
then wrote only the audited ext4 `system`, `system_ext` and `product` images
with 64 MiB sparse chunks. Every chunk succeeded, exact stock `vendor`/`odm`
and all OPlus mappings remained present, and the enforcing AVB/boot chain was
restored before the first Android boot.

The durable enforcing fix is an exact recovery-policy rule:

```text
genfscon tmpfs /block/sdc68 u:object_r:super_block_device:s0
```

The concrete extended-devt node is created by `tmpfs`, so the existing path
file-context and recovery `restorecon` were not sufficient across fastbootd's
separate boot. The boot audit now inspects the compiled policy with
`seinfo`, rather than accepting only the source rule. A rebuilt candidate
passed that audit and an enforcing hardware fastbootd test reported slot A,
exposed `super`, all five standard logical mappings and all ten preserved
OPlus mappings. No permissive domain or stock recovery staging is required by
that corrected recovery.

The generated full A/B installation ZIP is correctly signed and contains a
full ten-partition payload, but is not yet a safe replacement for that
bounded path. Its dynamic metadata lists only the five standard logical
partitions. Live Karen metadata has those plus ten OPlus partitions only in
`main_a`; update-engine's non-partial snapshot metadata updater deletes
target-suffix partitions absent from the manifest. A publishable standard
installer must model that preserved layout or use an audited partial-update
design. Device-specific side images should likewise be published only when
the final target-files configuration and installation order require them.

### Interactive checkout

The following fallback is useful while iterating on Android makefiles because
it avoids rebuilding the complete source derivation after every edit.
Prepare a Lineage 21 checkout without copying proprietary inputs into Git:

```sh
nix run .#extract-stock -- --profile boot
nix run .#extract-stock -- --profile lineage
nix shell nixpkgs#jq nixpkgs#python3 --command \
  scripts/prepare-lineage --full /path/to/lineage-21
```

Then build only the recovery-as-boot image. On NixOS, run the build inside the
repository's FHS shell so AOSP's generic Linux host tools can execute:

```sh
nix run /path/to/oneplus-nord2t-karen#android-fhs -- -c '
  source build/envsetup.sh
  export KAREN_FULL_SYSTEM=true
  lunch lineage_karen-ap2a-userdebug
  m bootimage systemimage systemextimage productimage \
    vendorimage odmimage vbmetaimage vbmetasystemimage vbmetavendorimage
  m checkvintf
  /path/to/oneplus-nord2t-karen/scripts/audit-lineage-vintf "$PWD"
 '
```

Omit `--full` and `KAREN_FULL_SYSTEM` when rebuilding only the recovery probe.
The FHS shell creates its cache directory before Soong starts and caps
`ccache` at 400 GB. Keep the checkout's `out` directory between runs as well;
its Ninja and Soong state avoids substantially more work than compiler cache
alone.

Do not flash the result until bootloader USB communication and exact stock
slot restoration have both been proven. The rest of this document records what
is needed to turn `karen` into an official, updatable device rather than a
one-off local build.

## Existing starting points

The known public attempts are small, abandoned Android 12/13-era scaffolds:

- [oneplus-karen-roms](https://github.com/oneplus-karen-roms);
- [Nord2T repositories](https://github.com/Nord2T);
- [ArrowOS `karen` tree](https://github.com/abhi0-tech/android_device_oneplus_karen).

They provide perhaps 10–20% of a useful bring-up starting point: partition
layout hints, product makefiles, some proprietary-file lists and initial
sepolicy. They are not suitable as a base to flash. Known issues include:

- no maintained releases or OTA channel;
- missing or empty kernel dependencies;
- stale Android 12 vendor blobs;
- mixed references to the Nord 2 codename `denniz`;
- incomplete IMS and hardware integration;
- `SELINUX_IGNORE_NEVERALLOWS` in the Arrow tree.

The October 2022 `oneplus-karen-roms` Lineage tree is a renamed `denniz`
starting point with `BUILD_WITHOUT_VENDOR`, build-break workarounds, policy
bypasses and no released ROM. Of its 51 listed proprietary paths, only 18 have
the same path in the extracted `.3001` partitions; IMS libraries have moved
and several old 32-bit entries no longer exist. It is useful for partition and
init hints, not as a tree to build or flash unchanged.

The useful modern source is OnePlus's MT6893 Android 14 kernel branch:

```text
oneplus/mt6893_14_14.0.0_nord_2t_5g
```

Repository:
[OnePlusOSS/android_kernel_oneplus_mt6893](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6893)

The relevant OnePlus branch is pinned for research at commit
`a5cdca1a88dc328a44dee724193830254fc551da`, with the associated MediaTek
modules at `a198b1d0e4ca41cf48d62793e65a9484ad833312`. These sources were last
synced for an older 2024 OxygenOS 14 release. They match the 4.19 kernel family,
but not the exact 2026 `.3001` binary baseline, so source availability does not
remove the kernel-maintenance work.

Both hashes are still the tips of OnePlus's only Android 14 Nord 2T branches
as checked on 2026-07-25; there is no newer official Karen kernel source to
select. The published tree itself identifies as 4.19.191. A practical update
track is therefore: first reconstruct the missing OPlus source layer and boot
that exact source baseline, then forward-port applicable maintained 4.19
security fixes with hardware regression tests. Rebasing Karen directly to a
current 5.10, 6.x or mainline kernel would require porting the MediaTek/OPlus
display, camera, modem/IMS, audio, charging, touch, sensors and power stack and
must be treated as a separate platform port.

### Reproducible source-kernel gate

The flake locks both official repositories and exposes a diagnostic build:

```sh
nix build .#karen-source-kernel-bootimage
```

On `s-tau` this reaches the pinned Lineage Soong bootstrap, then stops before
kernel compilation because generated kernel includes resolve through dangling
links. The published kernel checkout has 102 dangling symlinks, including the
14 include paths Soong requests at this stage. They target missing components
such as `vendor/oplus/kernel/oplus_performance`, charger, touchpanel, sensor,
secure, storage and audio sources. The separately published matching module
repository contains `vendor/mediatek/kernel_modules`; it does not supply the
referenced `vendor/oplus` tree.

This is an upstream source-completeness gate, not a compiler error. Creating
empty targets would be invalid because the selected defconfig enables the
corresponding OPlus features. Importing similarly named source from an
unrelated Oppo product would also lose device and release provenance. Until a
matching reviewable source layer is available, recovery and initial full
Lineage bring-up must retain the already verified `.3001` stock kernel, DTB
and DTBO. Such a build can establish userspace compatibility on this test
phone, but it cannot satisfy the eventual source-built-kernel requirement.

The verified full Android 14 OTA in this repository's manifest is the preferred
source for matching proprietary blobs. Rooting the currently installed system
is not a prerequisite. The
[UBports porting introduction](https://docs.ubports.com/en/latest/porting/introduction/Intro.html)
is useful background here: proprietary blobs are device- and Android-version
specific, and hardware bring-up is inherently iterative even when a generic
system image is involved.

## Why the old TWRP build is not flashable

The
[unofficial `karen` TWRP tree](https://github.com/oneplus-karen-roms/android_device_oneplus_karen-twrp)
is a historical scaffold, not a recovery for the installed build:

- it was last updated in October 2022 and is based on OxygenOS A.15;
- it embeds a 4.14.186 kernel and old `dtbo`, while `.3001` uses 4.19.191
  with different device-tree data;
- it declares recovery-as-boot, so flashing it replaces a boot slot rather
  than a separate recovery partition;
- [its open issue](https://github.com/oneplus-karen-roms/android_device_oneplus_karen-twrp/issues/2)
  says current `/data` could already not be mounted on Android 13;
- the current XDA thread reports that the early Nord 2T TWRP advice is obsolete
  on later software.

The layout and fstab can still be compared while building a fresh recovery
ramdisk. A test image must use the current partition facts and a compatible
kernel/device tree. LineageOS acceptance also requires a source-built kernel
for this non-GKI device and defaults to Lineage Recovery, so an updated TWRP
would only be a bring-up aid. The downloaded release and current stock boot
were unpacked and compared in the [TWRP image audit](twrp-audit.md).

## What root added and did not add

Magisk can patch the exact `.3001` stock `boot.img` after the bootloader is
unlocked. The patch must be made on this phone from its matching stock image;
using somebody else's patched boot image risks a non-booting slot. Unlocking
also wipes the phone.

Root is not needed to obtain `vendor`, `odm`, `system_ext`, `product`, stock
`boot`, `dtbo` or AVB metadata: `nix run .#extract-stock` extracts and verifies
those directly from the signed full OTA. Root was used only after that
baseline to collect live diagnostics and inspect partitions absent from the
payload.

Both live `vendor_boot` slots proved to be 64 MiB of zero bytes. The stock
kernel therefore uses its boot-header-v2 ramdisk and there is no
`vendor_boot` content to import. Slot A's live DTBO and AVB payload prefixes
match `.3001`; slot B retains a 2024-12-era boot generation. Nine modules were
loaded on stock: `bt_drv_6893`, `connfem`, `conninfra`,
`fmradio_drv_connac2x`, `fpsgo`, `gps_drv`, `trace_mmstat`,
`wlan_drv_gen4m` and `wmt_chrdev_wifi`.

The rooted kernel configuration confirms EROFS, F2FS, dm-verity, modules,
module signatures, overlayfs, pstore, SELinux and USB configfs. The local
capture is kept outside Git. Device-unique radio, calibration and persistent
partitions were not read and must never become porting blobs or repository
artifacts.

## Work estimate

For an experienced Android device maintainer, expect roughly 200–500 hours over
three to six months for an official-quality first port, followed by ongoing
maintenance. MediaTek IMS, camera, fingerprint, audio and proprietary firmware
make this substantially harder than compiling an existing official tree.

The [LineageOS submission guide](https://lineageos.github.io/lineage_wiki/submitting_device.html)
describes initial bring-up as weeks or months and requires continued support,
not a submit-and-forget tree.

## Deliverables

A serious port should eventually be separated into conventional Android source
repositories:

- `android_device_oneplus_karen`;
- a suitable common MT6893/OnePlus device tree if justified;
- `android_kernel_oneplus_mt6893`;
- proprietary vendor blobs and extraction scripts;
- optional hardware-specific repositories where upstream Lineage requires
  them.

This umbrella repository can keep research, manifests and host tools, but it is
not itself the eventual Lineage device tree.

## Bring-up sequence

1. Preserve verified stock recovery packages and a rootless inventory.
2. Use LineageOS 21 initially so Android 14 framework and `.3001` vendor
   interfaces match during bring-up; move to the current supported branch
   before proposing official support.
3. Import the OnePlus Android 14 kernel and module sources and make them build
   reproducibly with the matching toolchain.
4. Create a clean `karen` device tree from the actual Android 14 partition and
   VINTF data, not by renaming `denniz`.
5. Generate proprietary-file lists and extract matching blobs from the verified
   full OTA.
6. Build Lineage Recovery. Boot it temporarily only if this bootloader supports
   that operation; otherwise test an inactive boot slot only after an exact
   stock restoration route and slot-switch procedure are proven.
7. Bring up boot, decryption, dynamic partitions and A/B updates.
8. Bring up radio/IMS, SMS, emergency calls, Wi-Fi, Bluetooth, GNSS, audio,
   camera, fingerprint, NFC, sensors and charging.
9. Remove every permissive domain and policy bypass; ship SELinux enforcing.
10. Implement signed builds and an updater, then test clean install, OTA,
    rollback and slot failure handling repeatedly.
11. Either ship matching firmware or provide an installation process that puts
    both A/B slots on a known-good firmware version.
12. Test all hardware against the
    [LineageOS device-support requirements](https://github.com/LineageOS/charter/blob/main/device-support-requirements.md).
13. Publish device, kernel and vendor trees and send them to LineageOS developer
    relations for review.

## Minimum gate before flashing

The exact locked-stock roundtrip is complete. The phone was deliberately
unlocked again with its expected wipe; normal boot is exact rootless stock and
an explicit recovery request enters the corrected private Lineage Recovery.
Never relock a custom system. Before flashing, continue to require all of the
following:

- a bootable image produced from reviewable source;
- a current, exact `CPH2399` blob and firmware baseline;
- a tested way back to signed stock firmware;
- working USB recovery or bootloader communication on this host;
- an external copy of every destructive recovery package;
- a documented test matrix;
- acceptance that custom AVB relocking is not documented for this phone.

Official Lineage acceptance additionally requires continued security updates,
working hardware, encryption, SELinux enforcing, functioning upgrades and
maintainer availability. Passing a build is the beginning of the port, not its
completion.

Any future Android device-tree contributions should use Apache-2.0-compatible
licensing and any kernel changes must remain GPL-2.0-compatible. Preserve
upstream authorship and copyright instead of replacing it.
