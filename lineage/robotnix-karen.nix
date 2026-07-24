# SPDX-License-Identifier: MIT
{deviceTree}: {lib, ...}: {
  flavor = "lineageos";
  flavorVersion = "21.0";
  device = "karen";
  deviceDisplayName = "OnePlus Nord 2T";
  variant = "userdebug";
  release = "ap2a";
  stateVersion = "3";

  # Build scratch space is already isolated by Nix. Keeping ccache disabled
  # makes the result independent from mutable host state.
  ccache.enable = false;

  source.dirs."device/oneplus/karen".src = lib.mkForce deviceTree;
}
