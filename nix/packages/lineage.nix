# SPDX-License-Identifier: MIT
{
  artifacts,
  deviceTools,
  kernel,
  pkgs,
  robotnix,
  system,
  ...
}: let
  repositoryRoot = ../..;

  inherit
    (artifacts)
    adbPublicKey
    lineageWebviewArm64
    ;
  inherit
    (deviceTools)
    extractStock
    stockFrameworkVintf3001
    stockLineage3001
    ;
  inherit
    (kernel.nixos)
    oneplusControlKernelModules
    oneplusControlKernelSource
    ;

  karenDeviceTree =
    pkgs.runCommand "lineage-device-oneplus-karen" {
      nativeBuildInputs = [
        extractStock
        pkgs.mkbootimg-osm0sis
      ];
    } ''
      cp --no-preserve=ownership -r \
        ${repositoryRoot + /lineage/device/oneplus/karen} "$out"
      chmod -R u+w "$out"

      stock_dir="$TMPDIR/stock"
      unpack_dir="$TMPDIR/unpacked"
      nord2t-extract-stock --profile boot --output "$stock_dir"
      mkdir -p "$unpack_dir" "$out/prebuilt/dtbs"
      unpackbootimg -i "$stock_dir/images/boot.img" -o "$unpack_dir"

      install -m 0644 "$unpack_dir/boot.img-kernel" "$out/prebuilt/kernel"
      install -m 0644 \
        "$unpack_dir/boot.img-dtb" \
        "$out/prebuilt/dtbs/karen.dtb"
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
        import (repositoryRoot + /lineage/robotnix-karen.nix) {
          deviceTree = karenDeviceTree;
          insecureRecoveryAdb = true;
          lineageLockfile = robotnixLineage21Lock;
          vendorLineagePatches = robotnixVendorLineagePatches;
          webviewSource = lineageWebviewArm64;
        }
      )
    else null;

  karenSourceKernelRobotnix =
    if system == "x86_64-linux"
    then
      robotnix.lib.robotnixSystem (
        import (repositoryRoot + /lineage/robotnix-karen.nix) {
          buildSourceKernel = true;
          deviceTree = karenDeviceTree;
          insecureRecoveryAdb = true;
          kernelModules = oneplusControlKernelModules;
          kernelSource = oneplusControlKernelSource;
          lineageLockfile = robotnixLineage21Lock;
          vendorLineagePatches = robotnixVendorLineagePatches;
          webviewSource = lineageWebviewArm64;
        }
      )
    else null;

  karenSourceKernelFullRobotnix =
    if system == "x86_64-linux"
    then
      robotnix.lib.robotnixSystem (
        import (repositoryRoot + /lineage/robotnix-karen.nix) {
          buildSourceKernel = true;
          deviceTree = karenFullDeviceTree;
          fullSystem = true;
          kernelModules = oneplusControlKernelModules;
          kernelSource = oneplusControlKernelSource;
          lineageLockfile = robotnixLineage21Lock;
          vendorLineagePatches = robotnixVendorLineagePatches;
          webviewSource = lineageWebviewArm64;
        }
      )
    else null;

  karenSourceKernelKeyboundFullRobotnix =
    if system == "x86_64-linux" && adbPublicKey != null
    then
      robotnix.lib.robotnixSystem (
        import (repositoryRoot + /lineage/robotnix-karen.nix) {
          inherit adbPublicKey;
          buildSourceKernel = true;
          deviceTree = karenFullDeviceTree;
          fullSystem = true;
          kernelModules = oneplusControlKernelModules;
          kernelSource = oneplusControlKernelSource;
          lineageLockfile = robotnixLineage21Lock;
          vendorLineagePatches = robotnixVendorLineagePatches;
          webviewSource = lineageWebviewArm64;
        }
      )
    else null;

  karenFullRobotnix =
    if system == "x86_64-linux"
    then
      robotnix.lib.robotnixSystem (
        import (repositoryRoot + /lineage/robotnix-karen.nix) {
          deviceTree = karenFullDeviceTree;
          fullSystem = true;
          lineageLockfile = robotnixLineage21Lock;
          vendorLineagePatches = robotnixVendorLineagePatches;
          webviewSource = lineageWebviewArm64;
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
          bash \
            ${repositoryRoot + /scripts/audit-lineage-vintf} \
            "$ANDROID_BUILD_TOP"
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
          effective_config="$ANDROID_PRODUCT_OUT/obj/KERNEL_OBJ/.config"
          grep -Fxq 'CONFIG_KEXEC=y' "$effective_config"
          mkdir -p "$out"
          cp --reflink=auto "$ANDROID_PRODUCT_OUT/boot.img" "$out/boot.img"
          cp --reflink=auto "$ANDROID_PRODUCT_OUT/kernel" "$out/kernel"
          cp --reflink=auto "$effective_config" "$out/kernel.config"
        '';
      }
    else null;

  mkKarenSourceKernelFullImages = {
    name,
    robotnixSystem,
  }:
    robotnixSystem.config.build.mkAndroid {
      inherit name;
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
        bash \
          ${repositoryRoot + /scripts/audit-lineage-vintf} \
          "$ANDROID_BUILD_TOP"
        effective_config="$ANDROID_PRODUCT_OUT/obj/KERNEL_OBJ/.config"
        grep -Fxq 'CONFIG_KEXEC=y' "$effective_config"
        mkdir -p "$out"
        for image in \
          boot system system_ext product vendor odm \
          vbmeta vbmeta_system vbmeta_vendor; do
          cp --reflink=auto "$ANDROID_PRODUCT_OUT/$image.img" "$out/$image.img"
        done
        cp --reflink=auto "$ANDROID_PRODUCT_OUT/kernel" "$out/kernel"
        cp --reflink=auto "$effective_config" "$out/kernel.config"
      '';
    };

  karenSourceKernelFullImages =
    if system == "x86_64-linux"
    then
      mkKarenSourceKernelFullImages {
        name = "lineage-21-karen-source-kernel-full-images";
        robotnixSystem = karenSourceKernelFullRobotnix;
      }
    else null;

  karenSourceKernelKeyboundFullImages =
    if system == "x86_64-linux" && adbPublicKey != null
    then
      mkKarenSourceKernelFullImages {
        name = "lineage-21-karen-source-kernel-keybound-full-images";
        robotnixSystem = karenSourceKernelKeyboundFullRobotnix;
      }
    else null;
in {
  public =
    {
      android-fhs = androidFhs;
    }
    // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
      karen-bootimage = karenBootimage;
      karen-device-tree = karenDeviceTree;
      karen-full-images = karenFullImages;
      karen-source-kernel-bootimage = karenSourceKernelBootimage;
      karen-source-kernel-full-images = karenSourceKernelFullImages;
    }
    // pkgs.lib.optionalAttrs (karenSourceKernelKeyboundFullImages != null) {
      karen-source-kernel-keybound-full-images =
        karenSourceKernelKeyboundFullImages;
    };
}
