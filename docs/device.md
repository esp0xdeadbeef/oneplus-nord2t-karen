<!-- SPDX-License-Identifier: MIT -->

# Device inventory

The values below were collected from the connected European retail phone
through authorized, non-root ADB on 2026-07-24.

| Field | Value |
| --- | --- |
| Marketing name | OnePlus Nord 2T 5G |
| Model | `CPH2399` |
| Product | `CPH2399EEA` |
| Product device | `OP557AL1` |
| Community codename | `karen` |
| SoC | MediaTek MT6893 / Dimensity 1300 |
| ABI | `arm64-v8a` |
| Launch API | 31 |
| VNDK | 31 |
| Treble | enabled |
| Partitions | dynamic, virtual A/B |
| Active slot at initial capture | `b` |
| Active slot after `.3001` OTA | `a` |
| AVB | 1.2 |
| Data filesystem | F2FS |
| System/vendor/product | EROFS |

At the initial `.608` capture the phone reported:

- OxygenOS `CPH2399_14.0.0.608(EX01)`;
- Android 14;
- Android security patch `2024-12-05`;
- locked bootloader;
- green Verified Boot;
- OEM unlocking not allowed.

After installing the verified full EU OTA on 2026-07-24, the phone reported:

- OxygenOS `CPH2399_14.0.0.3001(EX01)`;
- Android security patch `2026-06-01`;
- active slot `a`;
- locked bootloader and green Verified Boot;
- SELinux enforcing and encrypted user data.

Later bring-up deliberately unlocked the bootloader and wiped userdata. The
current tested state is:

- active slot `a`;
- unlocked bootloader and orange Verified Boot;
- exact `.3001` stock kernel/DTB with a reproducibly Magisk-patched ramdisk;
- Magisk `30.7` additional setup completed;
- explicitly approved ADB shell root;
- SELinux still enforcing and userdata still encrypted.

These are observations, not build-time constants. Re-run the inventory after
each OTA:

```bash
nix run .#privacy -- inventory
```

## Rootless snapshot

Rooting before inventory is counterproductive: unlocking performs a factory
reset and changes the security state being measured. The public full OTA is a
better source for proprietary blobs, while rootless ADB can collect the
hardware and framework declarations needed for planning.

That rootless baseline was collected before unlocking. Root was added only
afterwards to inspect partitions absent from the OTA and loader failure state;
it must not replace the baseline security inventory.

`nord2t-snapshot` records only:

- an explicit allowlist of build and security properties;
- system package names, never the user-installed package list;
- declared features and HALs;
- partition names and mount types;
- VINTF manifests;
- kernel and SELinux state;
- the system OTA certificate archive;
- a SHA-256 manifest over the capture.

It intentionally does not query or store serial numbers, IMEIs, MAC addresses,
accounts, contacts, media, application data or user package names.

The original `.608` rootless capture is kept outside Git. It contains 90 files,
342 system packages and 434 HAL rows. Its `SHA256SUMS` manifest has SHA-256:

```text
3ff184cd2b22d1b71b09c6c277b2d9aacd982e893752328dcb7dede2f6234d53
```

The post-update `.3001` capture is also outside Git. It contains 12 files, 344
system packages and 436 HAL rows. Its `SHA256SUMS` manifest has SHA-256:

```text
a37868967bbf3bfa43b45bd3ba3bd260cee90ad7c8977cc2fa40290e53951711
```

Generate another capture after a future update:

```bash
nix run .#snapshot
```

The default output is below the Git-ignored `snapshots/` directory. Review any
capture before sharing it; a conservative collector cannot guarantee that a
vendor never embeds an identifier in an otherwise system-level diagnostic.
