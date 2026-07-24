<!-- SPDX-License-Identifier: MIT -->

# TWRP image audit

This is a static comparison only. Neither image was flashed.

## Inputs

- `twrp-3.7.0_12-1-UNOFFICIAL-karen.img`, downloaded from the
  [October 2022 prerelease](https://github.com/oneplus-karen-roms/android_device_oneplus_karen-twrp/releases/tag/3.7.0_12-1-UNOFFICIAL):
  SHA-256
  `08f73d93484188f56ef6590695e234ff8f464af15ac599f66f642e1e599574f2`.
- `boot.img`, extracted from the verified full
  `CPH2399_14.0.0.3001(EX01)` EU OTA: SHA-256
  `7ad447405db4e74276395123c8029c67c63adc3fc6d82c4c180ae6c2e31882c0`.

Both files are 64 MiB Android boot-header-v2 images. Their contents are not
interchangeable:

| Property | Unofficial TWRP | Stock `.3001` |
| --- | --- | --- |
| Kernel | 4.14.186+, built 2022-09-22 | 4.19.191+, built 2026-05-26 |
| Kernel payload | 15,942,656 bytes | 18,927,658 bytes |
| Ramdisk | 34,110,601 bytes | 20,827,665 bytes |
| DTB | 200,773 bytes | 210,513 bytes |
| DTB load address | `0x41f78000` | `0x47c80000` |
| Embedded recovery DTBO | 1,032,192 bytes | none |
| Header patch level | fake `2099-12` | `2026-06` |
| Build variant | `eng`, recovery flags | `user` |
| AVB footer | hash only, algorithm `NONE` | OnePlus RSA-signed |

The DTB payloads differ byte-for-byte. The old recovery's ramdisk also lacks
the current stock `fscompress` userdata flag. Its bundled 2022 userspace and
key-management libraries predate the installed Android 14 framework. This is
consistent with the tree's
[open Android 13 data-mount issue](https://github.com/oneplus-karen-roms/android_device_oneplus_karen-twrp/issues/2).

## Conclusion

The release image must not be flashed on `.3001`. It is recovery-as-boot, so it
would replace a boot slot, contains a different kernel/device tree and is not
signed by the stock AVB chain.

Simply combining its ramdisk with the current stock kernel would create an
unsigned hybrid with stale recovery userspace. Such an image might display a
UI while still failing decryption, dynamic-partition operations, USB or
slot-safe updates; producing one would not be meaningful evidence that it is
safe.

The reusable parts are limited to human-readable partition, fstab and init
hints. A real recovery experiment should be rebuilt from current sources and
current `.3001` facts, use a source-built 4.19 kernel for an eventual LineageOS
submission, and pass a no-flash audit before the bootloader is unlocked.
