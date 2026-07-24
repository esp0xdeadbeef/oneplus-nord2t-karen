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

Keep the generated patched image only as a local artifact. It is ignored by
Git and must not be published as a device-independent stock image.

## Restore stock boot

```bash
nix run .#stock-unroot -- --persist
```

This verifies the exact pinned stock image, repeats the model/build/unlock
checks, enters actual bootloader-fastboot and restores stock to only the
active `boot_<slot>`. It removes the standard `com.topjohnwu.magisk` manager
package after Android returns unless `--keep-app` is supplied.

Restoring stock boot removes executable Magisk root but may leave inert files
under encrypted userdata, such as prior module state. A factory reset is the
clean route if those remnants also need to be removed. The command does not
relock the bootloader. Relocking is a separate high-risk operation and must
not be attempted until every active partition is known to be signed,
unmodified stock.
