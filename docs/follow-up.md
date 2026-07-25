# LineageOS follow-up

Last updated: 2026-07-25

This is the resumable handoff for the current Karen LineageOS bring-up. It is
deliberately operational rather than a second porting guide; durable findings
and rationale remain in [lineage-port.md](lineage-port.md).

All `s-tau` names and paths below describe the repository owner's current
offloaded build session. They are not prerequisites for this port: builds may
run locally or on another sufficiently capable host. See the
[optional remote-build-host guide](remote-builder.md) for the host boundary,
rsync flow and artifact-return checks.

## Current checkpoint

- Git `main` and `origin/main` contain the stock roundtrip and OLED recovery
  checkpoints; commit the snapshot gate below before the next phone write.
- For this owner session, Android compilation is offloaded to `s-tau` because
  full builds exhausted the memory available on `l-esp`.
- The persistent checkout is
  `/home/deadbeef/build/lineage-21-karen-incremental`, bind-mounted at
  `/build` while an incremental build is active.
- User lingering is enabled for `deadbeef` on `s-tau`; transient build units
  otherwise stop when the final SSH session closes.
- The successful forced OLED-fix rebuild unit was
  `karen-lineage-oled-fix4.service`.
- The compiler cache is
  `/home/deadbeef/.cache/nord2t-ccache` on `s-tau`, with a 400 GB limit.
- The exact-stock relock and green/rootless boot completed successfully. The
  bootloader was then deliberately unlocked again, with the expected wipe.
  A recovery request currently enters the corrected private Lineage Recovery
  on slot A, while a normal boot still enters exact rootless stock userspace.
- A bounded read-only copy of the first 4 MiB of `super` found the expected 15
  active slot-A partitions plus nine COW snapshot partitions. A complete
  stock boot did not remove them, and bootloader-fastboot returned no usable
  `snapshot-update-status`. The next logical write remains blocked until
  stock fastbootd reports an unambiguous state.

### Exact stock restore and relock

The Lineage recovery-fastbootd slot workaround was not sufficient: it still
created no logical mappings. Staging the exact stock `boot_a`,
`vbmeta_system_a`, `vbmeta_vendor_a` and `vbmeta_a` supplied stock recovery
and stock fastbootd without touching a logical or unique partition. That
fastbootd correctly reported slot A and exposed explicit `_a` logical names.

The first bounded restore wrote exact stock `system_a`, then stopped before
writing `system_ext_a` because the add-on-capable Lineage `product_a`
allocation still held its large headroom. The restore order now shrinks and
writes exact stock `product_a` first. The complete retry then wrote all five
exact public-OTA logical images followed by the three stock AVB images and
stock `boot_a`. It never named an OPlus, radio, calibration or persistent
partition, and it left the already exact stock `dtbo` untouched.

The first stock system boot required a manual stock recovery factory reset
because Lineage userdata had the reverse incompatible encryption policy.
After setup, runtime reported exact `.3001`, slot A, encryption, SELinux
enforcing, shell-only ADB and no Magisk process/package or `su`. The
bootloader then accepted `fastboot flashing lock`, performed its mandatory
wipe and reported `unlocked=no`. The post-lock stock boot reports green
Verified Boot, `flash.locked=1`, vbmeta state `locked`, verity enforcing and
still no root.

### First successful full-system boot

The original system write was valid. The early reboot was an intentional
Android data-migration guard, not a kernel panic, display failure or AVB
failure. Private pstore logs showed normal first- and second-stage init,
successful F2FS `/data` mounting and an orderly shutdown. Lineage Recovery
then recorded the non-identifying command reason
`set_policy_failed:/data/app`: the retained stock userdata encryption policy
could not be reused by the new framework.

A private key-bound permissive bootpair produced the same recovery result,
excluding SELinux enforcement as the cause. The built-in Lineage factory
reset was then run because userdata was backed up and wipes were explicitly
authorized. No firmware, radio, calibration, persistent or OPlus logical
partition was read or written. The next boot reached Lineage setup and
completed successfully.

The temporary permissive bootpair was immediately replaced with the already
audited key-bound enforcing bootpair. The helper wrote only `vbmeta_a` and
`boot_a`. The enforcing reboot completed with:

- Lineage 21 / Android 14 on slot A;
- `sys.boot_completed=1`;
- file-based encryption active on F2FS `/data`;
- authenticated shell ADB and SELinux enforcing;
- unlocked bootloader signals `ro.boot.flash.locked=0` and Verified Boot
  `orange`;
- all tested framework binder services and core processes running.

The owner confirmed working display/touch, front and rear camera, audio and
internet. GNSS, calls/SMS/IMS, Bluetooth, fingerprint/NFC, sensors, MTP,
suspend/resume and broader charging behavior still need explicit manual
parity checks. The current boot image remains a private authenticated-ADB
bring-up image; it is not a release image.

Checkpoint work after the first boot adds separate `lineage-root`,
`lineage-root-full` and `lineage-unroot` interfaces. Minimal root is designed
to preserve useful debug observations by leaving Zygisk and concealment
modules disabled. Full root is a deliberate opt-in profile. Both are tied to
an explicit audited Lineage bundle, and unroot restores its exact
`vbmeta_a`/`boot_a` pair.

The old OxygenOS de-Google/package-disable profile was removed after the
working Lineage boot. Aurora Store is now a separate pinned installer and was
successfully installed on Lineage without F-Droid. Android 14 arm64
MindTheGapps is pinned as an explicit optional input for the planned
opinionated profile; vanilla and root-only variants remain separate.

The first standard MindTheGapps sideload correctly reached Lineage Recovery
but aborted before copying files because the three Lineage-owned images were
EROFS and `/mnt/system` could not be mounted read-write. No wipe followed that
failed add-on attempt and Lineage rebooted normally. The device tree now
builds `system`, `system_ext` and `product` as ext4 with explicit add-on
headroom, while exact stock `vendor`/`odm` stay EROFS.

The resulting vanilla bundle was built on `s-tau` and passed VINTF, boot, AVB,
filesystem and preserved-layout audits. Its sparse ext4 images expand to
977,920,000 bytes for `system`, 500,445,184 bytes for `system_ext` and
1,850,867,712 bytes for `product`; they retain at least 32 MiB, 64 MiB and
1.25 GiB of free space respectively. Together with exact stock `vendor` and
`odm`, the five standard images consume 4,935,397,376 bytes of the preserved
8,816,586,752-byte ceiling. A stale private ADB public key from an earlier
incremental recovery build was rejected by the audit; rebuilding the
uncompressed recovery ramdisk produced the clean vanilla candidate. Repeat
the normal Lineage Recovery add-on sideload before the first boot of this
candidate, followed by the required factory reset.

On the first stock-restore attempt from the earlier Lineage build, recovery
fastbootd returned an empty `current-slot` value even after bootloader-fastboot
had confirmed and selected slot A. The helper stopped before its first write.
It now records the verified bootloader slot across that exact transition and
accepts a missing fastbootd value only within the same process; a fresh
fastbootd invocation still has to round-trip through bootloader-fastboot. A
subsequent restore reached fastbootd but its empty value also prevented the
host client from expanding `system` to `system_a`; both bounded attempts were
rejected as a nonexistent target. The helper now uses explicit slot-A logical
names only after that same verified transition.

Explicit `system_a` was rejected too, confirming that fastbootd had created no
logical mappings at all. Ordinary recovery receives `_a` correctly, while
the stock MTK bootloader omits the AOSP-required `androidboot.slot_suffix`
only when it sets `boot-fastboot`. Karen has only one populated and supported
slot, so the boot image now supplies `_a` as a bounded device workaround.

The first hardware test of that boot-cmdline workaround confirmed `_a` in the
new ordinary recovery kernel command line, but fastbootd still returned an
empty `current-slot` and exposed neither `system` nor `system_a`. No logical
partition or stock image was written. The boot command line alone is
therefore insufficient; exact stock restore remains blocked until fastbootd's
slot source or logical-partition mapping path is corrected.

That same recovery exposed a separate reproducible black-screen issue. DRM,
DSI, framebuffer allocation and the recovery process were healthy, but
recovery's configured init-time blank/unblank power-cycle reset the OLED after
its brightness had already been applied. A live `lcd-backlight` brightness
reapply restored the UI immediately. Karen now leaves
`TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT` disabled and tests that it stays
disabled.

The first two incremental rebuild attempts exposed a second reproducibility
trap: the persistent Android checkout held an old regular BoardConfig copy,
then preserved an older source mtime after rsync. Kati consequently retained
the stale `true` property even when Ninja reported success. A new boot audit
now rejects the property inside the final ramdisk, not just in source. That
audit rejected the stale candidate. After explicitly synchronizing the device
tree and forcing Kati regeneration, the new key-bound OLED candidate passed
the full boot/filesystem/AVB audit and VINTF.

The bootloader was unlocked again and the earlier audited recovery was used
briefly as an ADB safety net. Only its `vbmeta_a` and `boot_a` were written.
The new audited pair then replaced those same two partitions. Without any
host brightness write, recovery came up on slot A with authenticated root
ADB, the blank/unblank property absent, DSI connected/enabled/on and one
non-zero brightness command. The prior init-time panel
disable/unprepare sequence was absent.

Staging only the exact `.3001` stock `boot_a` and three AVB images in
bootloader-fastboot provided a working recovery alternative. Stock fastbootd
reported `current-slot=a`, exposed `system_a` as logical and returned its
expected partition size. It did not expose the unsuffixed `system` alias.
The restore helper now probes both names after slot attestation and selects
the mapping fastbootd actually exposes; it still stops before writing when
neither mapping exists.

The corrected nine-image bundle completed 117,156 actions on `s-tau` in
1:10:10 and passed the boot, AVB, exact stock vendor/odm and size audit. Its
first VINTF check was rejected before any phone write: Lineage's empty
device-specific framework matrix did not declare the stock FCM-5
MediaTek/OPlus HALs. Candidate directory
`/home/deadbeef/build/lineage-21-karen-images-20260725-1` is therefore a
diagnostic artifact, not a flash candidate.

The exact stock framework matrix exposed two remaining facts: Android 14
needed the Android 12 VNDK snapshot for this stock vendor, and the OEM matrix
listed the live `vendor.mediatek.hardware.camera.isphal` 1.0 instance only as
1.1. Checkpoint `301ff4a` enables the real VNDK-31 APEX and adds a truthful
optional 1.0 declaration without importing a proprietary service. The
incremental rebuild installed `com.android.vndk.v31.apex`; `checkvintf`
subsequently passed against exact stock vendor/odm metadata for the live
`dsds` SKU.

Fresh candidate directory
`/home/deadbeef/build/lineage-21-karen-images-20260725-2` passed the complete
boot, authenticated-ADB, AVB-chain, exact stock vendor/odm and size audit.
Its five standard images total 2,802,786,304 bytes against the preserved
8,816,586,752-byte ceiling. The live-phone preflight also passed against the
exact slot-A `.3001` layout and rollback set.

The first bounded install attempt entered fastbootd and resized `system_a`,
then its first sparse data chunk failed with `Error reading sparse file`.
No Lineage data chunk had reported success. The exact restore action was run
without leaving fastbootd; it successfully rewrote all five stock standard
logical images plus stock slot-A boot/AVB metadata and rebooted. No OPlus
partition or `dtbo` was written. Android USB subsequently re-enumerated, but
the newly rebooted phone still needs its screen unlocked before the new host
ADB key can be authorized again, so post-restore property verification is
pending.

The write helper now waits five seconds after fastbootd enumeration and gives
each explicitly allowed partition one bounded full-image retry after a
transfer failure. The stock restore succeeding with the same raw-image
conversion is evidence for a transient endpoint/USB failure, not yet proof of
its exact cause. Repeat the complete stock preflight before another install.

Stock was authorized again and returned to the deliberately limited Magisk
debug root with `stock-root --persist --yes`; no Zygisk or concealment modules
were installed. The complete read-only preflight passed again. On the second
bounded install, every sparse chunk of `system_a`, `system_ext_a` and
`product_a` transferred and wrote successfully. The helper then entered
bootloader-fastboot and successfully wrote the three audited slot-A AVB
images and `boot_a`. It did not write `vendor`, `odm`, `dtbo` or any OPlus
logical partition.

After reboot, the phone remained in Android USB mode and exposed one
unauthorized ADB endpoint for more than six minutes; it did not re-enumerate
in fastboot. That proves neither a completed boot nor a bootloop. The
normal-user host key now lives in the persistent `.android` mount configured
by NixOS checkpoint `6b631d2f`; its contents remain outside Git. Lineage
rejected the Android Open Accessory HID registration, so the RSA dialog could
not be accepted remotely. The next safe action is to wake and unlock the
phone, approve that key, then inspect `sys.boot_completed`, SELinux and
general boot logs before deciding whether to continue or restore stock.

A key-bound fallback was prepared without weakening ADB authentication.
Checkpoint `d2b48f5` adds the opt-in `KAREN_DEBUG_ADB_KEYS` build variable and
makes the normal boot/image audits reject an embedded host key unless the
private bring-up flag is explicit. The incremental `s-tau` build completed in
2:58 and placed exactly one local Android public key in the boot ramdisk.

Both the complete private bundle and a smaller hybrid consisting of its new
`boot`/`vbmeta` pair plus the original candidate's other seven images passed
the complete explicit audit, including the AVB chain and exact stock
vendor/odm checks. Independent copies are stored in private directories under
`/home/deadbeef/build` on `s-tau` and the phone host; no key or key-derived
image is in Git. The enforcing variant is now the active bootpair.
`lineage-keybound-adb` verifies the matching local private key and can write
or restore only `vbmeta_a` and `boot_a`.

The scoped ten-image stock rollback set is protected by an explicit GC root
on `s-tau`:

```text
/home/deadbeef/build/gcroots/karen-stock-restore-3001
```

An independently rehashed copy is available on the phone host:

```text
/home/deadbeef/build/oneplus-nord2t-karen-stock-restore-3001
```

Neither location contains device-unique data; all files come from the pinned
public `.3001` OTA.

## Resume commands

Inspect the active or most recent build without starting a local Android
compile:

```bash
ssh s-tau \
  'systemctl --user show karen-lineage-vintf-vndk-retry2.service \
    -p ActiveState -p SubState -p Result -p ExecMainStatus'
ssh s-tau \
  'journalctl --user -u karen-lineage-vintf-vndk-retry2.service \
    -n 80 --no-pager'
```

The intended s-tau targets are:

```text
bootimage systemimage systemextimage productimage vendorimage odmimage
vbmetaimage vbmetasystemimage vbmetavendorimage
```

Do not replace them with `vbmeta_systemimage` or `vbmeta_vendorimage`; those
are not valid Ninja goals. Keep the real `/build` bind mount when reusing the
imported Ninja state. A symlink resolves back to the home path and invalidates
the absolute depfiles.

## Required order after the image build

1. Require a successful terminal systemd result and stage exactly the nine
   requested images outside `out/`.
2. Run `audit-lineage-images`. It must pass boot structure, authenticated ADB,
   complete AVB chaining, exact stock `vendor`/`odm` hashes and the preserved
   standard-image budget.
3. Build the host `checkvintf` target and run
   `scripts/audit-lineage-vintf /build` against the generated framework and
   exact stock vendor/odm VINTF metadata for the live `dsds` SKU.
4. Rsync the audited candidate directory from `s-tau` to the phone host and
   hash it again.
5. Run the read-only `preflight-lineage-userspace` from either the exact
   rooted stock baseline or the audited private Lineage Recovery. It must
   confirm slot A, the exact 15-partition `main` layout, 3,527,249,920
   preserved OPlus bytes, the 8,816,586,752-byte standard image ceiling and
   the absence of COW snapshot partitions.
6. Only when every previous gate is green, use the bounded
   `lineage-userspace install` action. It first stages exact stock boot/AVB
   metadata to obtain the tested stock fastbootd mappings, then writes
   `system`, `system_ext`, `product`, `boot_a`, `vbmeta_a`,
   `vbmeta_system_a` and `vbmeta_vendor_a`; it leaves live exact `vendor`,
   `odm`, `dtbo` and every OPlus logical partition untouched.
7. Verify boot, display, touch, encryption, ADB authorization, SELinux,
   telephony, Wi-Fi, Bluetooth, cameras, audio, sensors, GNSS, USB,
   suspend/resume and charging. Preserve only general logs; do not collect
   identifiers, calibration data or radio contents.
8. If the boot or runtime gate fails, keep the current USB mode and run the
   bounded `lineage-userspace restore` action with the local rollback
   directory. It restores the five standard logical images plus exact stock
   slot-A boot/AVB metadata and never names an OPlus partition.

## Hard stop conditions

- Do not flash a generated `super.img`; it cannot yet round-trip the ten OPlus
  logical partitions.
- Do not write slot-B logical placeholders as if they were an independent
  inactive system.
- Do not hide, delete or implicitly cancel COW snapshot partitions. Establish
  their Android merge status through stock fastbootd before continuing.
- Do not flash `oscaro`, `avicii` or `denniz` artifacts.
- Do not read or publish `nvram`, `nvdata`, calibration, persistent, radio or
  other device-unique partitions.
- Do not treat a successful compile as permission to flash. AVB, VINTF,
  rollback and live-layout preflight are separate mandatory gates.
- Never relock while any custom boot, recovery, AVB or logical image is
  installed. The only tested lock path is after the complete exact `.3001`
  stock restore and rootless runtime verification recorded above.

After each material result, update this file and
[lineage-port.md](lineage-port.md), commit with the required `Assisted-by`
trailer and push the WIP checkpoint.
