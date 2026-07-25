<!-- SPDX-License-Identifier: MIT -->

# Update and recovery

## Installed baseline

The phone originally ran `.608` with a 2024-12-05 Android security patch. The
OS Updater API entry for the EU `CPH2399EEA` track pointed directly to OPlus's
OTA CDN for full build `CPH2399_14.0.0.3001(EX01)`, with the 2026-06-01 patch.
Its target metadata, payload hashes, whole-file signature and signer
certificate were independently checked against this phone before installation.

The full `.3001` package was installed through OxygenOS Local install on
2026-07-24. It booted successfully on slot `a`; the locked bootloader, green
Verified Boot, enforcing SELinux and encrypted storage were retained.

For a future official update:

1. Charge the phone and connect it to a reliable network.
2. Verify that the update targets `CPH2399EEA` / `OP557AL1`.
3. Install it through the normal OxygenOS updater.
4. Allow the phone to reboot fully.
5. Re-enable USB debugging if the update reset it.
6. Verify the expected build and security patch before resuming port work.

Do not downgrade to `.2901` merely because it is recorded here.

## Validated local packages

The binary files are intentionally outside Git. Their expected properties are
in [`firmware/manifest.json`](../firmware/manifest.json).

| File | Purpose | Wipes data | SHA-256 |
| --- | --- | --- | --- |
| `CPH2399_14.0.0.3001_OTA.zip` | Current full EU OxygenOS 14 OTA | No | `4ca89d77ce64e09f1b061db69e5589be7ad60d2c0403b2e9217e47862352c41f` |
| `CPH2399_14.0.0.2901_OTA.zip` | Full EU OxygenOS 14 OTA | No | `32c2666db6d3ba3ef06367051498b45f53b6ba94133d43ff66d84025d007d013` |
| `CPH2399_OOS13_EU_rollback.zip` | Emergency rollback to OxygenOS 13 | **Yes** | `54c9dbb7f168978e609dc0fbab42128258be3b8a37e7bd1342eaf2c8554fd325` |

Both are ZIP64 archives. Info-ZIP may report malformed OnePlus vendor extra
fields; use 7-Zip for archive testing. Do not repack an OTA because that
invalidates its whole-file signature.

Verify the files from the repository:

```bash
nix run .#verify-firmware
```

Add a comparison with the certificate trusted by the connected phone:

```bash
nix run .#verify-firmware -- --device-cert
```

Extract the porting inputs from the current OTA without rooting the phone:

```bash
nix run .#extract-stock -- --profile boot
nix run .#extract-stock -- --profile blobs
nix run .#extract-stock -- --profile lineage
nix run .#extract-stock -- --profile restore
nix run .#extract-stock -- --profile firmware
nix run .#extract-stock -- --profile stock
```

The first profile produces the pinned `boot`, `dtbo`, `vbmeta`,
`vbmeta_system` and `vbmeta_vendor` images. `blobs` produces and rootlessly
expands all 13 EROFS system/vendor/OPlus partitions. `firmware` contains the
boot chain, modem, TEE and coprocessor images. The narrower `lineage` profile
produces only verified `vendor` and `odm` images plus their trees for the
full-system compatibility build. `stock` produces every one of the 34 payload
images without expanding the filesystem trees. All outputs are checked against
[`partitions-3001.json`](../firmware/partitions-3001.json), and the extractor
refuses to overwrite an existing destination.

The full OTA does not contain `vendor_boot`, although both live A/B
`vendor_boot` partitions exist. Rooted readback later proved that both
partitions are exactly 64 MiB of zero bytes, with identical SHA-256
`3b6a07d0d404fab4e23b6d34bc6696a6a312dd92821332385e5af7c01c421351`.
There is no hidden vendor ramdisk to copy into the recovery build.

The same allowlisted readback showed that slot A's padded `dtbo`, `vbmeta`,
`vbmeta_system` and `vbmeta_vendor` have exact `.3001` payload prefixes and
only zero padding. Slot B does not: its boot header reports security patch
`2024-12`, matching the older pre-update generation. Treat slot B as an older
fallback, not as a `.3001` restore source. Do not dump or publish `nvram`,
`nvdata`, `persist` or similar device-unique partitions.

The local, Git-ignored capture was made with an explicit allowlist:

```sh
for partition in \
  boot_a boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b \
  vbmeta_a vbmeta_b vbmeta_system_a vbmeta_system_b \
  vbmeta_vendor_a vbmeta_vendor_b; do
  adb exec-out \
    "su -c 'dd if=/dev/block/by-name/$partition bs=4194304 2>/dev/null'" \
    >"$CACHE/$partition.img"
done
```

Set `CACHE` to a private path outside Git and verify every byte size and hash
before use. Never broaden this loop to all entries below `/dev/block/by-name`.

The deeper preloader/BROM status and its additional prerequisites are tracked
in [hardbrick-recovery.md](hardbrick-recovery.md).

The pinned stock boot image can now also be used for a controlled Magisk root
probe and exact active-slot restoration. The default root command only creates
and audits a patched image; persistent root and unroot both require an
explicit `--persist` flag and confirmation. See
[stock-root.md](stock-root.md).

The verifier checks:

- byte size, MD5 and SHA-256;
- complete 7-Zip archive integrity;
- target product, product device, wipe flag and patch level;
- `payload.bin` size and SHA-256;
- update-engine metadata hash;
- the OTA certificate;
- the Android SignApk whole-file CMS signature;
- that the signature's certificate is the expected phone OTA certificate.

The full verification reads roughly 16 GB of archives several times and can
take a while.

The `.3001` metadata targets `CPH2399EEA` / `OP557AL1`, permits local update,
does not wipe data and declares patch level `2026-06-01`. `.2901` remains a
known-good older full OTA. The rollback file is destructive and exists only as
an emergency recovery asset.

## Safety boundaries

- Never use a firmware package for another OnePlus model or region.
- Never flash `oscaro`, `avicii` or `denniz` images.
- Prefer the signed stock updater over a generic fastboot flashing tool.
- Keep verified recovery packages on durable offline storage before any
  bootloader experiment.
- A MediaTek hard brick may require an OPlus-authenticated service tool; these
  files do not guarantee recovery.
- Bootloader unlocking wipes the phone.

Userspace fastboot (`adb reboot fastboot`) was initially tested
non-destructively while locked. Later testing after unlock proved the route
from fastbootd to bootloader-fastboot over a direct laptop USB port. Temporary
`fastboot boot` is not usable on this loader: both exact stock and patched
control images transferred, disconnected and returned through `lk_crash`.
Active-slot `boot_a` flashing was subsequently proven with the audited Magisk
control image and its exact pinned stock-unroot counterpart remains available.
An inactive-slot Lineage Recovery test subsequently proved the complete
`boot_b` write, slot switch, recovery boot and exact stock restoration
roundtrip.

The reverse non-destructive route was also verified on 2026-07-25:
`fastboot reboot fastboot` entered fastbootd from bootloader-fastboot and
`fastboot reboot bootloader` returned. `fastboot getvar is-userspace` reported
`yes` in fastbootd and `no` in the bootloader. The host labels these modes
`fastbootd` and `fastboot` respectively in the second column of
`fastboot devices`.

## Tested inactive-slot recovery roundtrip

The corrected Lineage Recovery bring-up image was tested on 2026-07-24 without
touching active `boot_a` or any dynamic partition. Before the test, rooted
stock readback saved the older original `boot_b` image outside Git and recorded
its exact 64 MiB size and SHA-256. Bootloader-fastboot then wrote the candidate
only to `boot_b` and selected slot `b`.

The phone booted Lineage Recovery visibly. Recovery ADB enumerated as
`lineage_karen`, reported `ro.boot.slot_suffix=_b` and supplied the intended
root diagnostic shell. The runtime ramdisk contained the first-stage fstab and
virtual A/B `snapuserd`; display, framebuffer, DRM and input devices were
present. This proves recovery execution, display and USB ADB, but does not yet
prove touch, decryption, sideload, fastbootd or installation of a complete ROM.

### Recovery OLED init

A later slot-A recovery repeatedly came up with working recovery ADB but a
black display. The panel had not failed to probe: DRM reported a connected,
enabled DSI connector with DPMS on and the expected 1080x2400 mode. The kernel
trace showed recovery first setting the OLED brightness, then immediately
disabling and unpreparing the panel during its configured init-time
blank/unblank cycle. The panel was prepared and enabled again, but no second
DSI brightness command followed.

Writing the existing brightness through the standard `lcd-backlight` LED
class as a `0 -> previous value` transition restored the recovery UI
immediately. This isolated the issue to
`TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT`, not late panel probing, DRM,
framebuffer allocation or the recovery process. Karen now leaves that option
at Lineage Recovery's default `false`, and a package-safety check rejects its
reintroduction.

The recovery ignored `adb reboot fastboot`. The tested exit command was:

```sh
adb shell reboot bootloader
```

In bootloader-fastboot, the following gates were checked before restoration:

```text
is-userspace: no
product: k6893v1_64_k419
hw-revision: ca00
unlocked: yes
```

Slot `a` was selected, the saved original image was written back only to
`boot_b`, and the phone was rebooted. Stock
`CPH2399_14.0.0.3001(EX01)` returned on slot `a` with SELinux enforcing. A
rooted live readback of `boot_b` exactly matched the pre-test SHA-256, while
the Magisk-patched stock `boot_a` and its approved root shell remained intact.

One loader quirk is worth preserving: after selecting an inactive slot,
`fastboot getvar current-slot` can continue to describe the currently running
bootloader slot until the next boot. Always verify the slot again from the
booted environment with `ro.boot.slot_suffix`; do not infer failure solely
from the immediate `getvar` result.

## Tested bootloader unlock

The bootloader was unlocked successfully on this `CPH2399` on 2026-07-24. The
important distinction is between Android userspace fastbootd and the actual
bootloader-fastboot implementation:

```sh
adb reboot fastboot
fastboot getvar is-userspace
# is-userspace: yes

fastboot reboot bootloader
fastboot getvar is-userspace
# is-userspace: no

fastboot getvar unlocked
# unlocked: no

fastboot flashing unlock
```

At the on-device confirmation screen, select **Unlock the bootloader** with the
volume keys and confirm with Power. This erases userdata. After confirmation,
the device remained in bootloader-fastboot and reported:

```text
unlocked: yes
current-slot: a
is-userspace: no
```

Two host-side details were essential:

- In fastbootd, `fastboot flashing unlock` returned `Unrecognized command
  flashing unlock`; `fastboot oem unlock` returned `Unable to open fastboot
  HAL`. Unlocking must be performed by bootloader-fastboot, not fastbootd.
- Behind the Lenovo Thunderbolt dock, the black bootloader screen displayed
  `Fastboot mode` and `DB: product name is match` but exposed no USB device at
  all. Moving the already-running fastbootd connection to a direct laptop USB
  port changed the topology from the dock path `1-5.4.1` to root-hub port
  `1-6`. After `fastboot reboot bootloader`, the phone then enumerated as
  ordinary `fastboot`, and the unlock command worked.

Use `fastboot getvar is-userspace` rather than the screen text to decide which
implementation is active. Do not proceed if it returns `yes`, if no fastboot
device is listed, or if the connected model is not the expected `CPH2399`.
Unlocking changes Verified Boot from green/locked to orange/unlocked until a
safe stock relock is deliberately performed.

## Tested exact-stock relock

On 2026-07-25 the phone completed the reverse Lineage-to-stock path before
relocking. Exact `.3001` stock boot/recovery and all three AVB images were
staged first in ordinary bootloader-fastboot. Stock recovery-fastbootd then
reported slot A and exposed the five explicit `_a` logical mappings. The
bounded restore wrote exact public-OTA `product`, `system`, `system_ext`,
`vendor` and `odm`, followed by stock AVB and `boot_a`. The already exact
stock `dtbo` and every OPlus or device-unique partition remained untouched.

Stock Android required a factory reset to replace Lineage's userdata
encryption policy. Before relocking, it booted exact `.3001` with encryption,
SELinux enforcing and no Magisk, `su` or elevated ADB. In
bootloader-fastboot, slot A was active, successful and bootable. The tested
lock command was:

```sh
fastboot flashing lock
```

After the on-device lock confirmation and mandatory second wipe,
bootloader-fastboot reported `unlocked=no`. The completed OxygenOS boot
reported green Verified Boot, `flash.locked=1`, vbmeta state `locked`, verity
enforcing and no root. This result authorizes only exact-stock relocking; it
does not make custom AVB relocking safe.

## Black “Fastboot mode” screen

After the privacy changes, one reboot entered a black OPlus/MediaTek screen
showing:

```text
Fastboot mode
DB: product name is match
```

Behind the Lenovo dock it did not expose a usable ADB or USB fastboot device,
and no partition had been flashed. A direct laptop port subsequently made this
same mode usable for the tested unlock above. If the loader is unreachable,
the recovery procedure that worked, consistent with the
[OnePlus Nord 2T manual](https://service.oneplus.com/content/dam/support/user-manuals/common/OnePlus_Nord_2T_5G_User_Manual_EN_20220919.pdf),
was:

1. Hold Power and Volume Up for at least 10 seconds.
2. Release both buttons.
3. Press only Power to start Android.

Avoid adding Volume Down unless deliberately entering recovery. Once Android
boots, verify `sys.boot_completed`, the lock state and Verified Boot through
the audit command.
