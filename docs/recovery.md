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
Verified Boot, enforcing SELinux and encrypted storage were retained. The
post-update privacy audit remained at 21/21 hardening and 24/24 de-Google
targets disabled.

For a future official update:

1. Charge the phone and connect it to a reliable network.
2. Verify that the update targets `CPH2399EEA` / `OP557AL1`.
3. Install it through the normal OxygenOS updater.
4. Allow the phone to reboot fully.
5. Re-enable USB debugging if the update reset it.
6. Run `nix run .#privacy -- audit`.
7. Reapply `nix run .#privacy -- degoogle` if the OTA restored package states.

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
nix run .#extract-stock -- --profile firmware
nix run .#extract-stock -- --profile stock
```

The first profile produces the pinned `boot`, `dtbo`, `vbmeta`,
`vbmeta_system` and `vbmeta_vendor` images. `blobs` produces and rootlessly
expands all 13 EROFS system/vendor/OPlus partitions. `firmware` contains the
boot chain, modem, TEE and coprocessor images. `stock` produces every one of
the 34 payload images without expanding the filesystem trees. All outputs are
checked against
[`partitions-3001.json`](../firmware/partitions-3001.json), and the extractor
refuses to overwrite an existing destination.

The full OTA does not contain `vendor_boot`, although both live A/B
`vendor_boot` partitions exist. The locked phone refused read-only fastboot
fetches of `boot` and `vendor_boot`; obtaining a live copy would therefore
require an unlocked or rooted route. Do not dump or publish `nvram`, `nvdata`,
`persist` or similar device-unique partitions.

The deeper preloader/BROM status and its additional prerequisites are tracked
in [hardbrick-recovery.md](hardbrick-recovery.md).

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

Userspace fastboot (`adb reboot fastboot`) was tested non-destructively on
`.3001`: it identified a secure, locked two-slot device and rebooted cleanly
back to green Verified Boot. This proves host communication with fastbootd,
not that bootloader-fastboot, temporary booting or arbitrary flashing is safe.

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
