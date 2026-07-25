# SPDX-License-Identifier: MIT
{
  description = "OnePlus Nord 2T (CPH2399/karen) privacy and recovery tooling";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.stock-firmware-3001 = {
    url = "file+https://gauss-componentotamanual.allawnofs.com/remove-eb367d9da8d667fc2c147fd33ff303b2/component-ota/26/06/16/a7aba01a7bed432681c874768c8c9b65.zip";
    flake = false;
  };
  inputs.magisk-apk = {
    url = "file+https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk";
    flake = false;
  };
  inputs.vector-module = {
    url = "file+https://github.com/JingMatrix/Vector/releases/download/v2.0/Vector-v2.0-3021-Release.zip";
    flake = false;
  };
  inputs.adaway-apk = {
    url = "file+https://github.com/AdAway/AdAway/releases/download/v6.1.4/AdAway-6.1.4-20241027.apk";
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

  outputs = {
    adaway-apk,
    hma-apk,
    self,
    magisk-apk,
    nixpkgs,
    oneplus-kernel-modules,
    oneplus-kernel-source,
    robotnix,
    shamiko-module,
    stock-firmware-3001,
    vector-module,
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

        magiskApk = pkgs.runCommand "Magisk-v30.7.apk" {} ''
          ln -s ${magisk-apk} "$out"
        '';

        vectorModule = pkgs.runCommand "Vector-v2.0-3021-Release.zip" {} ''
          ln -s ${vector-module} "$out"
        '';

        adawayApk = pkgs.runCommand "AdAway-6.1.4-20241027.apk" {} ''
          ln -s ${adaway-apk} "$out"
        '';

        hmaApk = pkgs.runCommand "HMA-V3.8.r499.3a346c0-release.apk" {} ''
          ln -s ${hma-apk} "$out"
        '';

        shamikoModule = pkgs.runCommand "Shamiko-v1.2.5-414-release.zip" {} ''
          ln -s ${shamiko-module} "$out"
        '';

        oneplusKernelSource = pkgs.runCommand "oneplus-karen-kernel-source" {} ''
          ln -s ${oneplus-kernel-source} "$out"
        '';

        oneplusKernelModules = pkgs.runCommand "oneplus-karen-kernel-modules" {} ''
          ln -s ${oneplus-kernel-modules}/vendor/mediatek/kernel_modules "$out"
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

        readGpt = pkgs.writeShellApplication {
          name = "nord2t-read-gpt";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gawk
            gnugrep
            gnused
            mtkclient
          ];
          text = builtins.readFile ./scripts/read-gpt;
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

        stockBoot3001 =
          pkgs.runCommand "CPH2399_14.0.0.3001-boot.img" {
            nativeBuildInputs = [extractStock];
          } ''
            stock_directory="$TMPDIR/stock"
            nord2t-extract-stock --profile boot --output "$stock_directory"
            install -m 0644 "$stock_directory/images/boot.img" "$out"
          '';

        stockLineage3001 =
          pkgs.runCommand "CPH2399_14.0.0.3001-lineage-vendor" {
            nativeBuildInputs = [extractStock];
          } ''
            nord2t-extract-stock --profile lineage --output "$out"
          '';

        stockRestore3001 =
          pkgs.runCommand "CPH2399_14.0.0.3001-lineage-restore" {
            nativeBuildInputs = [extractStock];
          } ''
            nord2t-extract-stock --profile restore --output "$out"
          '';

        stockFrameworkVintf3001 =
          pkgs.runCommand "CPH2399_14.0.0.3001-framework-vintf" {
            nativeBuildInputs = [pkgs.erofs-utils];
          } ''
            matrix="$TMPDIR/compatibility_matrix.device.xml"
            fsck.erofs \
              --extract="$matrix" \
              --path=/system/etc/vintf/compatibility_matrix.device.xml \
              --no-preserve \
              ${stockRestore3001}/images/system.img >/dev/null
            test -s "$matrix"
            install -D -m 0644 \
              "$matrix" \
              "$out/compatibility_matrix.device.xml"
          '';

        stockRoot = pkgs.writeShellApplication {
          name = "nord2t-stock-root";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gawk
            gnugrep
            gnused
            mkbootimg-osm0sis
            unzip
          ];
          text =
            builtins.replaceStrings
            [
              "@MAGISK_APK@"
              "@STOCK_BOOT@"
            ]
            [
              "${magiskApk}"
              "${stockBoot3001}"
            ]
            (builtins.readFile ./scripts/stock-root);
        };

        stockUnroot = pkgs.writeShellApplication {
          name = "nord2t-stock-unroot";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gawk
            gnugrep
            gnused
          ];
          text = builtins.replaceStrings ["@STOCK_BOOT@"] ["${stockBoot3001}"] (
            builtins.readFile ./scripts/stock-unroot
          );
        };

        stockRootFull = pkgs.writeShellApplication {
          name = "nord2t-stock-root-full";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gawk
            gnugrep
            gnused
            stockRoot
          ];
          text =
            builtins.replaceStrings
            [
              "@VECTOR_MODULE@"
              "@ADAWAY_APK@"
              "@HMA_APK@"
              "@SHAMIKO_MODULE@"
            ]
            [
              "${vectorModule}"
              "${adawayApk}"
              "${hmaApk}"
              "${shamikoModule}"
            ]
            (builtins.readFile ./scripts/stock-root-full);
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

        auditLineageImages = pkgs.writeShellApplication {
          name = "nord2t-audit-lineage-images";
          runtimeInputs = with pkgs; [
            android-tools
            auditBoot
            coreutils
            extractStock
            gnugrep
            jq
          ];
          text = builtins.replaceStrings ["@PARTITION_MANIFEST@"] ["${./firmware/partitions-3001.json}"] (
            builtins.readFile ./scripts/audit-lineage-images
          );
        };

        preflightLineageUserspace = pkgs.writeShellApplication {
          name = "nord2t-preflight-lineage-userspace";
          runtimeInputs = with pkgs; [
            android-tools
            auditLineageImages
            coreutils
            gawk
            gnused
            jq
          ];
          text = builtins.replaceStrings ["@PARTITION_MANIFEST@"] ["${./firmware/partitions-3001.json}"] (
            builtins.readFile ./scripts/preflight-lineage-userspace
          );
        };

        lineageUserspace = pkgs.writeShellApplication {
          name = "nord2t-lineage-userspace";
          runtimeInputs = with pkgs; [
            android-tools
            coreutils
            gawk
            gnused
            jq
            preflightLineageUserspace
          ];
          text = builtins.replaceStrings ["@PARTITION_MANIFEST@"] ["${./firmware/partitions-3001.json}"] (
            builtins.readFile ./scripts/lineage-userspace
          );
        };

        lineageKeyboundAdb = pkgs.writeShellApplication {
          name = "nord2t-lineage-keybound-adb";
          runtimeInputs = with pkgs; [
            android-tools
            auditLineageImages
            coreutils
            gawk
            gnugrep
            gnused
            libarchive
            mkbootimg-osm0sis
          ];
          text = builtins.readFile ./scripts/lineage-keybound-adb;
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

        karenFullDeviceTree = pkgs.runCommand "lineage-device-oneplus-karen-full" {} ''
          cp --no-preserve=ownership -r ${karenDeviceTree} "$out"
          chmod -R u+w "$out"

          mkdir -p \
            "$out/prebuilt/stock" \
            "$out/prebuilt/stock-framework-vintf" \
            "$out/prebuilt/stock-vintf"
          install -m 0644 \
            ${stockLineage3001}/images/vendor.img \
            "$out/prebuilt/stock/vendor.img"
          install -m 0644 \
            ${stockLineage3001}/images/odm.img \
            "$out/prebuilt/stock/odm.img"
          install -m 0644 \
            ${stockLineage3001}/trees/vendor/etc/fstab.mt6893 \
            "$out/rootdir/etc/fstab.mt6893.full"
          install -m 0644 \
            ${stockFrameworkVintf3001}/compatibility_matrix.device.xml \
            "$out/prebuilt/stock-framework-vintf/compatibility_matrix.device.xml"
          cp --no-preserve=ownership -r \
            ${stockLineage3001}/trees/vendor/etc/vintf \
            "$out/prebuilt/stock-vintf/vendor"
          cp --no-preserve=ownership -r \
            ${stockLineage3001}/trees/odm/etc/vintf \
            "$out/prebuilt/stock-vintf/odm"
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
              erofs-utils
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
            export CCACHE_MAXSIZE=400G
            mkdir -p "$CCACHE_DIR"
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
                insecureRecoveryAdb = true;
                lineageLockfile = robotnixLineage21Lock;
                vendorLineagePatches = robotnixVendorLineagePatches;
              }
            )
          else null;

        karenSourceKernelRobotnix =
          if system == "x86_64-linux"
          then
            robotnix.lib.robotnixSystem (
              import ./lineage/robotnix-karen.nix {
                buildSourceKernel = true;
                deviceTree = karenDeviceTree;
                insecureRecoveryAdb = true;
                kernelSource = oneplusKernelSource;
                lineageLockfile = robotnixLineage21Lock;
                vendorLineagePatches = robotnixVendorLineagePatches;
              }
            )
          else null;

        karenFullRobotnix =
          if system == "x86_64-linux"
          then
            robotnix.lib.robotnixSystem (
              import ./lineage/robotnix-karen.nix {
                deviceTree = karenFullDeviceTree;
                fullSystem = true;
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

        karenFullImages =
          if system == "x86_64-linux"
          then
            karenFullRobotnix.config.build.mkAndroid {
              name = "lineage-21-karen-full-images";
              makeTargets = [
                "bootimage"
                "systemimage"
                "systemextimage"
                "productimage"
                "vendorimage"
                "odmimage"
                "vbmetaimage"
                "vbmetasystemimage"
                "vbmetavendorimage"
                "checkvintf"
              ];
              installPhase = ''
                bash ${./scripts/audit-lineage-vintf} "$ANDROID_BUILD_TOP"
                mkdir -p "$out"
                for image in \
                  boot system system_ext product vendor odm \
                  vbmeta vbmeta_system vbmeta_vendor; do
                  cp --reflink=auto "$ANDROID_PRODUCT_OUT/$image.img" "$out/$image.img"
                done
              '';
            }
          else null;

        karenSourceKernelBootimage =
          if system == "x86_64-linux"
          then
            karenSourceKernelRobotnix.config.build.mkAndroid {
              name = "lineage-21-karen-source-kernel-bootimage";
              makeTargets = ["bootimage"];
              installPhase = ''
                mkdir -p "$out"
                cp --reflink=auto "$ANDROID_PRODUCT_OUT/boot.img" "$out/boot.img"
                cp --reflink=auto "$ANDROID_PRODUCT_OUT/kernel" "$out/kernel"
              '';
            }
          else null;
      in
        {
          android-fhs = androidFhs;
          adaway-apk = adawayApk;
          audit-boot = auditBoot;
          audit-lineage-images = auditLineageImages;
          default = nord2tPrivacy;
          extract-stock = extractStock;
          firmware-3001 = stockFirmware3001;
          hma-apk = hmaApk;
          lineage-keybound-adb = lineageKeyboundAdb;
          lineage-userspace = lineageUserspace;
          magisk-apk = magiskApk;
          oneplus-kernel-modules = oneplusKernelModules;
          oneplus-kernel-source = oneplusKernelSource;
          privacy = nord2tPrivacy;
          preflight-lineage-userspace = preflightLineageUserspace;
          probe-preloader = probePreloader;
          read-gpt = readGpt;
          shamiko-module = shamikoModule;
          snapshot = snapshotDevice;
          stock-boot-3001 = stockBoot3001;
          stock-framework-vintf-3001 = stockFrameworkVintf3001;
          stock-lineage-3001 = stockLineage3001;
          stock-restore-3001 = stockRestore3001;
          stock-root = stockRoot;
          stock-root-full = stockRootFull;
          stock-unroot = stockUnroot;
          vector-module = vectorModule;
          verify-firmware = verifyFirmware;
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          karen-bootimage = karenBootimage;
          karen-device-tree = karenDeviceTree;
          karen-full-images = karenFullImages;
          karen-source-kernel-bootimage = karenSourceKernelBootimage;
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
        lineage-userspace = {
          type = "app";
          program = "${self.packages.${system}.lineage-userspace}/bin/nord2t-lineage-userspace";
        };
        lineage-keybound-adb = {
          type = "app";
          program = "${self.packages.${system}.lineage-keybound-adb}/bin/nord2t-lineage-keybound-adb";
        };
        audit-boot = {
          type = "app";
          program = "${self.packages.${system}.audit-boot}/bin/nord2t-audit-boot";
        };
        audit-lineage-images = {
          type = "app";
          program = "${self.packages.${system}.audit-lineage-images}/bin/nord2t-audit-lineage-images";
        };
        privacy = {
          type = "app";
          program = "${self.packages.${system}.privacy}/bin/nord2t-privacy";
        };
        preflight-lineage-userspace = {
          type = "app";
          program = "${self.packages.${system}.preflight-lineage-userspace}/bin/nord2t-preflight-lineage-userspace";
        };
        probe-preloader = {
          type = "app";
          program = "${self.packages.${system}.probe-preloader}/bin/nord2t-probe-preloader";
        };
        read-gpt = {
          type = "app";
          program = "${self.packages.${system}.read-gpt}/bin/nord2t-read-gpt";
        };
        snapshot = {
          type = "app";
          program = "${self.packages.${system}.snapshot}/bin/nord2t-snapshot";
        };
        stock-root = {
          type = "app";
          program = "${self.packages.${system}.stock-root}/bin/nord2t-stock-root";
        };
        stock-root-full = {
          type = "app";
          program = "${self.packages.${system}.stock-root-full}/bin/nord2t-stock-root-full";
        };
        stock-unroot = {
          type = "app";
          program = "${self.packages.${system}.stock-unroot}/bin/nord2t-stock-unroot";
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
          audit-lineage-images
          extract-stock
          lineage-keybound-adb
          lineage-userspace
          privacy
          preflight-lineage-userspace
          probe-preloader
          read-gpt
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
              pkgs.gawk
              pkgs.gnugrep
            ];
            src = ./.;
          } ''
            bash "$src"/tests/package-safety.sh
            touch "$out"
          '';

        preloader-safety =
          pkgs.runCommand "nord2t-preloader-safety" {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gawk
              pkgs.gnugrep
              pkgs.gnused
            ];
            src = ./.;
          } ''
            bash "$src"/tests/preloader-safety.sh
            touch "$out"
          '';

        stock-boot-safety =
          pkgs.runCommand "nord2t-stock-boot-safety" {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
            ];
            src = ./.;
          } ''
            bash "$src"/tests/stock-boot-safety.sh
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
