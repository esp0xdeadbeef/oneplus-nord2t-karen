# SPDX-License-Identifier: MIT
{
  deviceTree,
  lineageLockfile,
  vendorLineagePatches,
}: {lib, ...}: {
  flavor = "lineageos";
  flavorVersion = "21.0";
  device = "karen";
  deviceDisplayName = "OnePlus Nord 2T";
  variant = "userdebug";
  release = "ap2a";
  stateVersion = "3";

  # This derivation builds only the temporary recovery-as-boot probe. Disable
  # ADB authentication so a freshly wiped device can provide bring-up logs.
  # BoardConfig.mk scopes the resulting WITH_ADB_INSECURE setting to this
  # explicit environment marker.
  envVars.KAREN_RECOVERY_BRINGUP = "true";

  # Build scratch space is already isolated by Nix. Keeping ccache disabled
  # makes the result independent from mutable host state.
  ccache.enable = false;

  # Robotnix's generated Lineage lock also contains TheMuppets vendor trees
  # for every supported phone. Karen has no matching entry and derives its
  # stock inputs independently, so do not realize those unrelated blobs.
  source.manifest.lockfile = lib.mkForce lineageLockfile;
  source.dirs."device/oneplus/karen".src = lib.mkForce deviceTree;

  # The current pinned Lineage 21 vendor revision has the Android 14
  # bootanimation layout. Robotnix 21.0 selects its older patch by default,
  # while its newer `-21` patch applies cleanly to this exact source.
  source.dirs."vendor/lineage".patches = lib.mkForce vendorLineagePatches;
}
