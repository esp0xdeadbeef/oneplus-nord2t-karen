# LineageOS follow-up

Last updated: 2026-07-25

This is the resumable handoff for the current Karen LineageOS bring-up. It is
deliberately operational rather than a second porting guide; durable findings
and rationale remain in [lineage-port.md](lineage-port.md).

## Current checkpoint

- Git `main` and `origin/main` both contain code checkpoint `301ff4a`.
- The repository worktree was clean after that push.
- Android compilation runs only on `s-tau`.
- The persistent checkout is
  `/home/deadbeef/build/lineage-21-karen-incremental`, bind-mounted at
  `/build` while an incremental build is active.
- User lingering is enabled for `deadbeef` on `s-tau`; transient build units
  otherwise stop when the final SSH session closes.
- The successful VINTF rebuild unit was
  `karen-lineage-vintf-vndk-retry2.service`.
- The compiler cache is
  `/home/deadbeef/.cache/nord2t-ccache` on `s-tau`, with a 400 GB limit.
- The phone is on the exact `.3001` stock baseline, slot A, unlocked and using
  only the basic Magisk debugging root. No Lineage userspace image has been
  written.

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
8,816,586,752-byte ceiling. It is the first host-approved flash candidate,
but it has not yet passed the live-phone preflight and has not been written.

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
5. Run the read-only `preflight-lineage-userspace` with stock Android still
   booted. It must confirm slot A, the exact 15-partition `main` layout,
   3,527,249,920 preserved OPlus bytes and the 8,816,586,752-byte standard
   image ceiling.
6. Only when every previous gate is green, use the bounded
   `lineage-userspace install` action. It writes `system`, `system_ext`,
   `product`, `boot_a`, `vbmeta_a`, `vbmeta_system_a` and
   `vbmeta_vendor_a`; it leaves live exact `vendor`, `odm`, `dtbo` and every
   OPlus logical partition untouched.
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
- Do not flash `oscaro`, `avicii` or `denniz` artifacts.
- Do not read or publish `nvram`, `nvdata`, calibration, persistent, radio or
  other device-unique partitions.
- Do not treat a successful compile as permission to flash. AVB, VINTF,
  rollback and live-layout preflight are separate mandatory gates.
- Do not relock the bootloader during bring-up.

After each material result, update this file and
[lineage-port.md](lineage-port.md), commit with the required `Assisted-by`
trailer and push the WIP checkpoint.
