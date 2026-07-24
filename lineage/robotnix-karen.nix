# SPDX-License-Identifier: MIT
{
  deviceTree,
  extractStock,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  karenDeviceTree =
    pkgs.runCommand "lineage-device-oneplus-karen" {
      nativeBuildInputs = [
        extractStock
        pkgs.mkbootimg-osm0sis
      ];
    } ''
      cp --no-preserve=ownership -r ${deviceTree} "$out"
      chmod -R u+w "$out"

      stock_dir="$TMPDIR/stock"
      unpack_dir="$TMPDIR/unpacked"
      nord2t-extract-stock --profile boot --output "$stock_dir"
      mkdir -p "$unpack_dir" "$out/prebuilt/dtbs"
      unpackbootimg -i "$stock_dir/images/boot.img" -o "$unpack_dir"

      install -m 0644 "$unpack_dir/boot.img-kernel" "$out/prebuilt/kernel"
      install -m 0644 "$unpack_dir/boot.img-dtb" "$out/prebuilt/dtbs/karen.dtb"
      install -m 0644 "$stock_dir/images/dtbo.img" "$out/prebuilt/dtbo.img"
    '';
in {
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

  source.dirs."device/oneplus/karen".src = lib.mkForce karenDeviceTree;
}
