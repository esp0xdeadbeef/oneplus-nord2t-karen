# LineageOS root and unroot

The Lineage port has separate helpers from the stock `.3001` workflow. They
accept a complete, already audited enforcing Lineage image directory so the
exact unmodified `boot.img` and matching `vbmeta.img` remain the rollback
source. Never pass a permissive diagnostic bundle.

## Minimal root

Create a private Magisk-patched boot image without flashing:

```bash
nix run .#lineage-root -- /path/to/lineage-images \
  --allow-embedded-adb-key \
  --output /private/path/magisk-lineage.img
```

Omit `--allow-embedded-adb-key` for a normal release-style bundle. Add
`--persist` only after the patch and source audits pass:

```bash
nix run .#lineage-root -- /path/to/lineage-images \
  --allow-embedded-adb-key \
  --output /private/path/magisk-lineage.img \
  --persist
```

The helper verifies the complete source bundle, an Android 14 Lineage runtime
on slot A, an unlocked bootloader, encryption and SELinux enforcing. Magisk
patching runs in an isolated temporary directory on the phone. The resulting
image must preserve the stock kernel, DTB, command line, boot layout and
enforcing mode while changing only the ramdisk. Magisk leaves the boot
image's own unsigned AVB hash descriptor stale after that change, so the
helper rebuilds that `Algorithm NONE` footer and verifies it before any write.

The persistent path enters ordinary bootloader-fastboot and writes only
`boot_a`. It does not enable Zygisk, install concealment modules or change
Magisk's denylist. This is the preferred rooted state for ROM debugging.
Karen's bootloader rejected temporary `fastboot boot` during bring-up, so the
helper deliberately does not advertise a temporary mode that cannot be
trusted on this device.

Minimal root assumes a clean Magisk userdata baseline. If the full profile was
used previously, remove its modules and reset its settings before unrooting;
restoring boot images makes module data inert but does not erase `/data/adb`.

The unlocked bring-up `vbmeta_a` has verification-disable flags. A rooted boot
therefore intentionally differs from its original boot hash descriptor.
Unroot restores both original images as a matched pair.

## Exact unroot

From running Lineage:

```bash
nix run .#lineage-unroot -- /path/to/lineage-images \
  --allow-embedded-adb-key \
  --persist
```

From a bootloop with the phone already in ordinary bootloader-fastboot:

```bash
nix run .#lineage-unroot -- /path/to/lineage-images \
  --allow-embedded-adb-key \
  --persist \
  --from-fastboot
```

This writes only the audited `vbmeta_a` and `boot_a` pair. The normal path
waits for encrypted, enforcing Lineage to return, confirms `magiskd` is gone
and removes the Magisk app unless `--keep-app` is supplied. Module files in
userdata can remain inert after unroot; remove them through Magisk before
unrooting if a clean module state matters.

## Full root profile

The full profile is explicitly separate because it changes what apps can
observe and can obscure useful bring-up failures:

```bash
nix run .#lineage-root-full -- /path/to/lineage-images \
  --allow-embedded-adb-key \
  --persist
```

It first establishes the same minimal pinned Magisk root when needed, then:

- enables Zygisk;
- installs pinned Vector and Shamiko modules;
- installs Hide My Applist and AdAway;
- creates Magisk's Systemless Hosts module;
- leaves Magisk denylist enforcement off as required by Shamiko;
- adds no package to the denylist unless `--denylist` is repeated explicitly.

Shell root must be approved in the Magisk app before the full helper can
install modules. Use minimal root while debugging Lineage itself; use the full
profile only when concealment behavior is the thing being tested.

All generated rooted images and Android authorization material remain outside
Git. These workflows do not read or write radio, calibration, persistent or
OPlus logical partitions, and they never relock the bootloader.
