# SPDX-License-Identifier: MIT
{
  description = "OnePlus Nord 2T (CPH2399/karen) privacy and recovery tooling";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.stock-firmware-3001 = {
    url = "file+https://gauss-componentotamanual.allawnofs.com/remove-eb367d9da8d667fc2c147fd33ff303b2/component-ota/26/06/16/a7aba01a7bed432681c874768c8c9b65.zip";
    flake = false;
  };
  inputs.robotnix = {
    url = "github:nix-community/robotnix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    robotnix,
    stock-firmware-3001,
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
        ...
      }: let
        auroraStore = pkgs.fetchurl {
          url = "https://f-droid.org/repo/com.aurora.store_75.apk";
          hash = "sha256-xM4N8Luw6Cvk5L19ij4ADwjgRFcYfVYP4so65SlBv0k=";
        };

        stockFirmware3001 = pkgs.runCommand "CPH2399_14.0.0.3001_OTA.zip" {} ''
          ln -s ${stock-firmware-3001} "$out"
        '';

        nord2tPrivacy = pkgs.writeShellApplication {
          name = "nord2t-privacy";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gnugrep
            gnused
          ];
          text = builtins.replaceStrings ["@AURORA_APK@"] ["${auroraStore}"] (
            builtins.readFile ./scripts/nord2t-privacy
          );
        };

        probePreloader = pkgs.writeShellApplication {
          name = "nord2t-probe-preloader";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gnugrep
            gnused
            mtkclient
          ];
          text = builtins.readFile ./scripts/probe-preloader;
        };

        extractStock = pkgs.writeShellApplication {
          name = "nord2t-extract-stock";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            erofs-utils
            jq
            payload-dumper-go
          ];
          text =
            builtins.replaceStrings
            [
              "@FIRMWARE_MANIFEST@"
              "@PARTITION_MANIFEST@"
              "@DEFAULT_FIRMWARE@"
            ]
            [
              "${./firmware/manifest.json}"
              "${./firmware/partitions-3001.json}"
              "${stockFirmware3001}"
            ]
            (builtins.readFile ./scripts/extract-stock);
        };

        auditBoot = pkgs.writeShellApplication {
          name = "nord2t-audit-boot";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            extractStock
            file
            findutils
            gawk
            gnugrep
            libarchive
            mkbootimg-osm0sis
          ];
          text = builtins.readFile ./scripts/audit-boot-image;
        };

        snapshotDevice = pkgs.writeShellApplication {
          name = "nord2t-snapshot";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            findutils
            gnugrep
            gnused
          ];
          text = builtins.readFile ./scripts/snapshot-device;
        };

        verifyFirmware = pkgs.writeShellApplication {
          name = "nord2t-verify-firmware";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gawk
            gnugrep
            jq
            openssl
            p7zip
          ];
          text = builtins.replaceStrings ["@FIRMWARE_MANIFEST@"] ["${./firmware/manifest.json}"] (
            builtins.readFile ./scripts/verify-firmware
          );
        };

        karenDeviceTree =
          pkgs.runCommand "lineage-device-oneplus-karen" {
            nativeBuildInputs = [
              extractStock
              pkgs.mkbootimg-osm0sis
            ];
          } ''
            cp --no-preserve=ownership -r ${./lineage/device/oneplus/karen} "$out"
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

        robotnixLineage21Lock = let
          upstreamLock =
            builtins.fromJSON
            (builtins.readFile "${robotnix}/flavors/lineageos/lineage-21.0/repo.lock");
          entries =
            pkgs.lib.filterAttrs
            (
              _: entry:
                !pkgs.lib.hasPrefix
                "https://github.com/TheMuppets/"
                entry.project.repo_ref.repo_url
            )
            upstreamLock.entries;
        in
          pkgs.writeText "lineage-21-karen-repo.lock" (
            builtins.toJSON (upstreamLock // {inherit entries;})
          );

        robotnixVendorLineagePatches = [
          "${robotnix}/flavors/lineageos/0001-Remove-LineageOS-keys-21.patch"
          (pkgs.replaceVars
            "${robotnix}/flavors/lineageos/0002-bootanimation-Reproducibility-fix-21.patch"
            {
              inherit (pkgs) imagemagick;
            })
          "${robotnix}/flavors/lineageos/0003-kernel-Set-constant-kernel-timestamp-21.patch"
          "${robotnix}/flavors/lineageos/0004-dont-run-repo-during-build.patch"
        ];

        androidFhs = pkgs.buildFHSEnv {
          name = "nord2t-android-fhs";
          multiArch = pkgs.stdenv.hostPlatform.isx86_64;
          targetPkgs = fhsPkgs:
            with fhsPkgs; [
              android-tools
              bash
              bc
              binutils
              bison
              ccache
              coreutils
              curl
              elfutils
              file
              findutils
              flex
              fontconfig
              freetype
              gawk
              gcc
              gcc.cc
              git
              git-lfs
              git-repo
              gnugrep
              gnupg
              gnused
              gnumake
              gperf
              imagemagick
              jdk17
              libxcrypt-legacy
              libxml2
              libxslt
              lz4
              lzop
              m4
              nettools
              openssl
              openssl.dev
              patch
              patchelf
              perl
              pngcrush
              procps
              python3
              rsync
              schedtool
              squashfsTools
              unzip
              util-linux
              which
              zip
              zlib
              yaml-cpp
            ];
          multiPkgs = fhsPkgs:
            with fhsPkgs;
              [
                libcxx
                libgcc
                ncurses
                readline
                zlib
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
                fhsPkgs.glibc_multi
              ];
          runScript = "bash";
          profile = ''
            unset LD_LIBRARY_PATH
            unset NIX_CFLAGS_COMPILE
            unset NIX_CFLAGS_LINK
            unset NIX_LDFLAGS
            export ALLOW_NINJA_ENV=true
            export USE_CCACHE=1
            export CCACHE_EXEC=/usr/bin/ccache
            export CCACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/nord2t-ccache"
            export ANDROID_JAVA_HOME=${pkgs.jdk17.home}
            export TMPDIR=/tmp
            export LC_ALL=C
            export LANG=C
          '';
        };

        karenRobotnix =
          if system == "x86_64-linux"
          then
            robotnix.lib.robotnixSystem (
              import ./lineage/robotnix-karen.nix {
                deviceTree = karenDeviceTree;
                lineageLockfile = robotnixLineage21Lock;
                vendorLineagePatches = robotnixVendorLineagePatches;
              }
            )
          else null;

        karenBootimage =
          if system == "x86_64-linux"
          then
            karenRobotnix.config.build.mkAndroid {
              name = "lineage-21-karen-bootimage";
              makeTargets = ["bootimage"];
              installPhase = ''
                mkdir -p "$out"
                cp --reflink=auto "$ANDROID_PRODUCT_OUT/boot.img" "$out/boot.img"
              '';
            }
          else null;
      in
        {
          android-fhs = androidFhs;
          audit-boot = auditBoot;
          default = nord2tPrivacy;
          extract-stock = extractStock;
          firmware-3001 = stockFirmware3001;
          privacy = nord2tPrivacy;
          probe-preloader = probePreloader;
          snapshot = snapshotDevice;
          verify-firmware = verifyFirmware;
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          karen-bootimage = karenBootimage;
          karen-device-tree = karenDeviceTree;
        }
    );

    apps = eachSystem (
      {system, ...}: {
        default = self.apps.${system}.privacy;
        android-fhs = {
          type = "app";
          program = "${self.packages.${system}.android-fhs}/bin/nord2t-android-fhs";
        };
        extract-stock = {
          type = "app";
          program = "${self.packages.${system}.extract-stock}/bin/nord2t-extract-stock";
        };
        audit-boot = {
          type = "app";
          program = "${self.packages.${system}.audit-boot}/bin/nord2t-audit-boot";
        };
        privacy = {
          type = "app";
          program = "${self.packages.${system}.privacy}/bin/nord2t-privacy";
        };
        probe-preloader = {
          type = "app";
          program = "${self.packages.${system}.probe-preloader}/bin/nord2t-probe-preloader";
        };
        snapshot = {
          type = "app";
          program = "${self.packages.${system}.snapshot}/bin/nord2t-snapshot";
        };
        verify-firmware = {
          type = "app";
          program = "${self.packages.${system}.verify-firmware}/bin/nord2t-verify-firmware";
        };
      }
    );

    checks = eachSystem (
      {
        pkgs,
        system,
      }: {
        inherit
          (self.packages.${system})
          audit-boot
          extract-stock
          privacy
          probe-preloader
          snapshot
          verify-firmware
          ;

        shellcheck =
          pkgs.runCommand "nord2t-shellcheck" {
            nativeBuildInputs = [pkgs.shellcheck];
            src = ./.;
          } ''
            shellcheck "$src"/scripts/*
            shellcheck "$src"/tests/*.sh
            touch "$out"
          '';

        firmware-metadata =
          pkgs.runCommand "nord2t-firmware-metadata" {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.jq
            ];
            src = ./.;
          } ''
            bash "$src"/tests/firmware-metadata.sh
            touch "$out"
          '';

        package-safety =
          pkgs.runCommand "nord2t-package-safety" {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
            ];
            src = ./.;
          } ''
            bash "$src"/tests/package-safety.sh
            touch "$out"
          '';
      }
    );

    devShells = eachSystem (
      {pkgs, ...}: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            android-tools
            coreutils
            curl
            erofs-utils
            git
            git-lfs
            git-repo
            jq
            libarchive
            mkbootimg-osm0sis
            mtkclient
            openssl
            p7zip
            payload-dumper-go
            shellcheck
          ];
        };
      }
    );
  };
}
