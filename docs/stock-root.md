<!-- SPDX-License-Identifier: MIT -->

# Stock root and unroot

The flake pins both inputs used by this workflow:

- the official Magisk `v30.7` APK from the upstream `topjohnwu/Magisk`
  release;
- the exact `boot.img` extracted from the pinned official
  `CPH2399_14.0.0.3001(EX01)` EU OTA.

`flake.lock` fixes the downloaded NAR contents. The scripts independently
require Magisk APK SHA-256
`e0d32d2123532860f97123d927b1bb86c4e08e6fd8a48bfc6b5bee0afae9ebd5`
and stock boot SHA-256
`7ad447405db4e74276395123c8029c67c63adc3fc6d82c4c180ae6c2e31882c0`.
They also check the expected byte sizes. The APK is never fetched at runtime.

The optional full stack pins one source build and three independent release
artifacts:

| Component | Version | Upstream artifact | SHA-256 |
| --- | --- | --- | --- |
| Vector | 2.0 (3021) | exact `JingMatrix/Vector` Git revision plus Nix Gradle dependency lock | `b66605a0cf2cdbac9ca9accc9e47edc203791d3374d59fed2fa11f5a654f8333` |
| Shamiko | 1.2.5 (414) | [`LSPosed/LSPosed.github.io`](https://github.com/LSPosed/LSPosed.github.io/releases/tag/shamiko-414) release ZIP | `308d31b2f52a80e49eb58f46bc4c764a6588a79e4b8d101b44860832023f88b4` |
| Hide My Applist | 3.8 (499) | [LSPosed module repository](https://github.com/Xposed-Modules-Repo/com.tsng.hidemyapplist/releases/tag/499-3.8.r499.3a346c0) APK | `0adaa6bcdf7ee1e9e1c310f33b86f2f4d03f8839a10be8384e34d6cb5bd99c39` |
| AdAway | 6.1.4 | [`AdAway/AdAway`](https://github.com/AdAway/AdAway/releases/tag/v6.1.4) APK | `09f8e1528a53e5ffad59e57a174e90d4e10c5092bf4f6a60ab6594f046614417` |

`flake.lock` fixes every source or release NAR. `gradle/vector-deps.json`
fixes Vector's Maven inputs. `stock-root-full` additionally checks each raw
file's byte size and SHA-256 before it accesses the phone.

Realizing `stock-root` or `stock-unroot` for the first time can require the
roughly 5.6 GB OTA because Nix derives the stock boot image from that source.
Afterwards the Nix store reuses the verified result.

## Create a patched image

With Android fully booted, USB debugging authorized and the phone connected
directly to the laptop:

```bash
nix run .#stock-root
```

The default action:

1. refuses anything except model `CPH2399`, device `OP557AL1` and installed
   build `CPH2399_14.0.0.3001(EX01)`;
2. verifies both pinned inputs;
3. installs the pinned Magisk app;
4. uses the APK's own ARM64 `boot_patch.sh` and binaries in a temporary,
   unprivileged `/data/local/tmp` directory;
5. preserves dm-verity and force-encryption settings;
6. pulls the result to
   `./magisk-patched-CPH2399-3001-v30.7.img`;
7. verifies its size, boot header, kernel and DTB against stock and requires
   the ramdisk to differ.

No partition is written in this default mode. Use `--output FILE` to select a
different new path. Existing output files are never overwritten.

## Temporary root probe

```bash
nix run .#stock-root -- --boot
```

This checks that the bootloader is unlocked, enters fastbootd first, then
enters actual bootloader-fastboot and sends only `fastboot boot`. On this
OnePlus loader a fully transferred temporary boot can end host-side with
`Status read failed (No such device)`. The script accepts only that known
disconnect form, waits for Android, and prints the exact `su` verification
command. A returned Android system is not proof that the downloaded image was
used; root must be confirmed:

```bash
adb shell su -c id
```

Grant the request in the Magisk app when prompted. Output containing
`uid=0(root)` proves the patched ramdisk ran. If Android reports no root, do
not infer that the patched image itself is bad: the current loader may have
fallen back to the slotted image after its `lk_crash` path.

That fallback is now confirmed on the test phone. The temporary Magisk image
transferred in full, the loader disconnected with `Status read failed`, and
Android returned with boot reason `lk_crash`, without `magiskd` or `su`. The
helper now treats that state as a failed temporary probe instead of reporting
success.

## Persistent stock root

```bash
nix run .#stock-root -- --persist
```

After all patch and bootloader checks, the script discovers the active slot
from bootloader-fastboot and asks for the literal confirmation `CPH2399`. It
then writes only `boot_a` or `boot_b`, whichever is active, and reboots. It
does not write `vbmeta`, `vendor_boot`, `super`, userdata, the inactive boot
slot or any device-unique partition. `--yes` may skip the prompt in an already
supervised workflow.

The persistent path was tested on slot `a` on 2026-07-24. Bootloader-fastboot
reported successful send and write of exactly 64 MiB to `boot_a`; Android then
returned with normal `PMIC_cold_reboot`, and `magiskd` ran as root. Magisk may
still request its one-time additional setup before exposing `su` to ADB. That
setup and its requested reboot also completed successfully. After allowing
only the `[SharedUID] Shell` policy in Magisk, the final probe returned:

```text
uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

Keep the generated patched image only as a local artifact. It is ignored by
Git and must not be published as a device-independent stock image.

## Full root stack

Full root enables two optional capabilities beyond plain Magisk root:

- an Xposed-compatible hooking framework can change system and app behavior
  without rebuilding the ROM;
- AdAway can provide system-wide host-level blocking through Magisk's
  Systemless Hosts overlay instead of occupying Android's single VPN slot.

Install the complete pinned stack with:

```bash
nix run .#stock-root-full -- --persist
```

The command requires the same exact `CPH2399` / `OP557AL1` `.3001` baseline
and unlocked bootloader as `stock-root`. It asks for `CPH2399-full` before
making changes unless `--yes` is supplied. If approved Magisk root is already
working, it does not flash the boot slot again. Otherwise it invokes the
pinned persistent `stock-root` path first.

The helper then:

1. verifies all four extra inputs by byte size and raw SHA-256;
2. installs the AdAway and Hide My Applist APKs for user 0;
3. enables Zygisk in Magisk 30.7;
4. disables Magisk's built-in denylist enforcement, as explicitly required by
   Shamiko;
5. adds only denylist targets supplied on the command line;
6. installs the Vector and Shamiko Magisk modules;
7. creates Magisk's built-in-style Systemless Hosts module without overwriting
   an existing hosts module;
8. reboots and verifies root, Zygisk, both Android packages and all three
   Magisk modules.

Shamiko reads Magisk's denylist, but its own upstream instructions require
**Enforce DenyList** to remain off. Add a complete package or one exact process
with repeatable arguments:

```bash
nix run .#stock-root-full -- --persist \
  --denylist com.example.app \
  --denylist com.example.app:isolated_process
```

No package is added by default because the correct targets depend on the
owner's installed apps. Re-running the helper is idempotent for the pinned
apps and modules and can add more targets.

Two deliberate manual steps remain:

- open Vector, enable Hide My Applist and select only its required scopes;
- open AdAway, choose root-based blocking and apply the desired hosts sources.

The complete stack was installed and verified on the test phone on
2026-07-24. It returned on slot `a` with Magisk `30.7:MAGISK:R`; Vector created
its runtime directory, Zygisk was enabled, Shamiko and Systemless Hosts were
active, and denylist enforcement returned disabled as required.

Vector subsequently masked the Android property view as `green/locked`, while
the raw kernel command line remained `orange/unlocked`. Re-running the full
stack or the Android-driven unroot route therefore checks the kernel command
line when approved root is available. If that source cannot be read, the
helper fails conservatively rather than trusting a disagreement. Every actual
boot write still rechecks `unlocked: yes` in bootloader-fastboot.

The test phone was later returned to plain Magisk for unmasked debugging.
While root was still available, Zygisk was disabled, the exact
`zygisk_vector`, `zygisk_shamiko` and `hosts` module directories were removed,
and the Hide My Applist and AdAway packages were uninstalled. The pinned
`stock-unroot --persist --yes` route then restored exact stock `boot_a`; a
completed rootless boot exposed the real `unlocked/orange` properties and no
`magiskd`. Finally, the pinned `stock-root --persist --yes` route restored only
Magisk 30.7. Approved root works, SELinux remains enforcing, Zygisk remains
disabled, the three modules remain absent, and both the Android properties and
raw kernel command line report `unlocked/orange`.

This cleanup before unrooting is significant. `stock-unroot` deliberately
changes only the active boot image and removes the Magisk app; it does not
delete module or app state from encrypted userdata. Re-rooting without first
removing or disabling that state can reactivate the previous full stack.

### Xposed Edge

Xposed Edge is a good example of the additional behavior an Xposed-compatible
framework can provide, including edge gestures, key remapping and system
actions beyond typical custom-ROM settings. It is not part of the automated
stack. The last known release is 8.0.1 from 2022, its Google Play listing has
been removed, and there is no current developer-controlled release endpoint
that this flake can pin. Pulling a privileged hooking module from an arbitrary
APK mirror would undermine the purpose of a reproducible privacy setup.

If a legitimate developer-signed copy becomes available, add it as a separate
locked input with a pinned signing certificate and content hash before
installation. Do not substitute an unofficial repack.

Vector, Shamiko and Hide My Applist substantially expand the trusted computing
base: they inject code into Zygote or system/app processes. Shamiko is also
distributed as a release binary rather than an auditable open-source build.
These tools can improve control and compatibility, but they are not a security
upgrade and do not guarantee Play Integrity or banking-app acceptance.

## Restore stock boot

```bash
nix run .#stock-unroot -- --persist
```

This verifies the exact pinned stock image, repeats the model/build/unlock
checks, enters actual bootloader-fastboot and restores stock to only the
active `boot_<slot>`. It removes the standard `com.topjohnwu.magisk` manager
package after Android returns unless `--keep-app` is supplied.

Restoring stock boot removes executable Magisk root but may leave inert files
under encrypted userdata, such as prior module state, AdAway, Hide My Applist
and their settings. A factory reset is the clean route if those remnants also
need to be removed. The command does not relock the bootloader. Relocking is a
separate high-risk operation and must not be attempted until every active
partition is known to be signed, unmodified stock.

If Android cannot boot, enter actual bootloader-fastboot over the direct USB
port and use:

```bash
nix run .#stock-unroot -- --persist --from-fastboot
```

That mode additionally requires the tested bootloader product
`k6893v1_64_k419`, hardware revision `ca00`, `is-userspace: no` and an unlocked
bootloader before it writes the active slot. It does not depend on authorized
ADB. If ADB does not return after the write, app removal cannot be automated.
