# SPDX-License-Identifier: MIT
{
  description = "OnePlus Nord 2T 5G (CPH2399/karen) recovery and LineageOS tooling";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.stock-firmware-3001 = {
    url = "file+https://gauss-componentotamanual.allawnofs.com/remove-eb367d9da8d667fc2c147fd33ff303b2/component-ota/26/06/16/a7aba01a7bed432681c874768c8c9b65.zip";
    flake = false;
  };
  inputs.magisk-apk = {
    url = "file+https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk";
    flake = false;
  };
  inputs.mindthegapps-14-arm64 = {
    url = "file+https://github.com/MindTheGapps/14.0.0-arm64/releases/download/MindTheGapps-14.0.0-arm64-20250203_200051/MindTheGapps-14.0.0-arm64-20250203_200051.zip";
    flake = false;
  };
  inputs.vector-source = {
    url = "git+https://github.com/JingMatrix/Vector.git?rev=76141fed151f49b818144d54f2ebb6ab9a2df11c&submodules=1";
    flake = false;
  };
  inputs.adaway-source = {
    url = "git+https://github.com/AdAway/AdAway.git?rev=89dc7277f5bd539ba108c20a857aae6e93199856";
    flake = false;
  };
  inputs.hma-apk = {
    url = "file+https://github.com/Xposed-Modules-Repo/com.tsng.hidemyapplist/releases/download/499-3.8.r499.3a346c0/HMA-V3.8.r499.3a346c0-release.apk";
    flake = false;
  };
  inputs.shamiko-module = {
    url = "file+https://github.com/LSPosed/LSPosed.github.io/releases/download/shamiko-414/Shamiko-v1.2.5-414-release.zip";
    flake = false;
  };
  inputs.robotnix = {
    url = "github:nix-community/robotnix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.oneplus-kernel-source = {
    url = "github:OnePlusOSS/android_kernel_oneplus_mt6893/a5cdca1a88dc328a44dee724193830254fc551da";
    flake = false;
  };
  inputs.oneplus-kernel-modules = {
    url = "github:OnePlusOSS/android_vendor_mediatek_kernel_modules_mt6893/a198b1d0e4ca41cf48d62793e65a9484ad833312";
    flake = false;
  };

  outputs = inputs @ {
    nixpkgs,
    self,
    ...
  }: let
    eachSystem = function:
      nixpkgs.lib.genAttrs
      [
        "aarch64-linux"
        "x86_64-linux"
      ]
      (
        system:
          function {
            inherit system;
            pkgs = import nixpkgs {inherit system;};
          }
      );
  in {
    formatter = eachSystem ({pkgs, ...}: pkgs.alejandra);

    packages = eachSystem (
      {
        pkgs,
        system,
      }:
        import ./nix/packages
        (inputs
          // {
            inherit pkgs system;
          })
    );

    apps = eachSystem (
      {
        pkgs,
        system,
      }:
        import ./nix/apps.nix {
          inherit pkgs self system;
        }
    );

    checks = eachSystem (
      {
        pkgs,
        system,
      }:
        import ./nix/checks.nix {
          inherit pkgs self system;
        }
    );

    devShells = eachSystem (
      {pkgs, ...}:
        import ./nix/dev-shell.nix {
          inherit pkgs;
        }
    );
  };
}
