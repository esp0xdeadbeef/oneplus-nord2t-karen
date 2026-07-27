# SPDX-License-Identifier: MIT
{
  artifacts,
  oneplus-kernel-source,
  pkgs,
  ...
}: let
  repositoryRoot = ../..;

  inherit
    (artifacts)
    adawayApk
    auroraStore
    hmaApk
    magiskApk
    shamikoModule
    stockFirmware3001
    vectorModule
    vectorSigningAndroid
    ;

  mtkclientKaren = pkgs.mtkclient.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        (repositoryRoot
          + /patches/mtkclient/0001-handshake-connected-preloader-without-da-state.patch)
        (repositoryRoot
          + /patches/mtkclient/0002-probe-oplus-preloader-for-meta-fastboot.patch)
      ];
  });

  adbKeyGenerator = pkgs.writeShellApplication {
    name = "nord2t-adb-key-generator";
    runtimeInputs = with pkgs; [
      age
      android-tools
      coreutils
      gitMinimal
      gnused
      sops
    ];
    text = builtins.readFile (repositoryRoot + /scripts/adb-key-generator);
  };

  vectorSigningKeyGenerator = pkgs.writeShellApplication {
    name = "nord2t-vector-signing-key-generator";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      jdk21
      jq
      openssl
      sops
    ];
    text =
      builtins.readFile
      (repositoryRoot + /scripts/vector-signing-key-generator);
  };

  kernelModuleSigningKeyGenerator = pkgs.writeShellApplication {
    name = "nord2t-kernel-module-signing-key-generator";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      gnugrep
      jq
      openssl
      sops
    ];
    text =
      builtins.readFile
      (repositoryRoot + /scripts/kernel-module-signing-key-generator);
  };

  kernelModuleOwnerBuild = pkgs.writeShellApplication {
    name = "nord2t-kernel-module-owner-build";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      jq
      nix
      openssl
      sops
    ];
    text =
      builtins.readFile
      (repositoryRoot + /scripts/kernel-module-owner-build);
  };

  kernelModuleSignFile = pkgs.stdenv.mkDerivation {
    pname = "nord2t-kernel-module-sign-file";
    version = "4.19.191";
    src = oneplus-kernel-source;
    nativeBuildInputs = [pkgs.pkg-config];
    buildInputs = [pkgs.openssl];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      "$CC" \
        $NIX_CFLAGS_COMPILE \
        scripts/sign-file.c \
        -o nord2t-kernel-module-sign-file \
        $(pkg-config --cflags --libs openssl)
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -D -m 0755 \
        nord2t-kernel-module-sign-file \
        "$out/bin/nord2t-kernel-module-sign-file"
      runHook postInstall
    '';
  };

  kernelModuleOwnerSign = pkgs.writeShellApplication {
    name = "nord2t-kernel-module-owner-sign";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gitMinimal
      gnugrep
      jq
      openssl
      sops
      kernelModuleSignFile
    ];
    text =
      builtins.readFile
      (repositoryRoot + /scripts/kernel-module-owner-sign);
  };

  vectorOwnerBuildIntermediate = pkgs.writeShellApplication {
    name = "nord2t-vector-owner-build-intermediate";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      jq
      nix
      sops
    ];
    text =
      builtins.readFile
      (repositoryRoot + /scripts/vector-owner-build-intermediate);
  };

  vectorOwnerSign = pkgs.writeShellApplication {
    name = "nord2t-vector-owner-sign";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gitMinimal
      jdk21
      jq
      gnused
      sops
      unzip
      zip
    ];
    text =
      builtins.replaceStrings
      ["@APKSIGNER@"]
      ["${vectorSigningAndroid.androidsdk}/libexec/android-sdk/build-tools/36.0.0/apksigner"]
      (
        builtins.readFile
        (repositoryRoot + /scripts/vector-owner-sign)
      );
  };

  ownerSignApk = pkgs.writeShellApplication {
    name = "nord2t-owner-sign-apk";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      jdk21
      jq
      gnused
      sops
    ];
    text =
      builtins.replaceStrings
      ["@APKSIGNER@"]
      ["${vectorSigningAndroid.androidsdk}/libexec/android-sdk/build-tools/36.0.0/apksigner"]
      (
        builtins.readFile
        (repositoryRoot + /scripts/owner-sign-apk)
      );
  };

  installAurora = pkgs.writeShellApplication {
    name = "nord2t-install-aurora";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gnugrep
      gnused
    ];
    text = builtins.replaceStrings ["@AURORA_APK@"] ["${auroraStore}"] (
      builtins.readFile (repositoryRoot + /scripts/install-aurora)
    );
  };

  probePreloader = pkgs.writeShellApplication {
    name = "nord2t-probe-preloader";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gnugrep
      gnused
      mtkclientKaren
    ];
    text = builtins.readFile (repositoryRoot + /scripts/probe-preloader);
  };

  readGpt = pkgs.writeShellApplication {
    name = "nord2t-read-gpt";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gawk
      gnugrep
      gnused
      mtkclientKaren
    ];
    text = builtins.readFile (repositoryRoot + /scripts/read-gpt);
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
        "${repositoryRoot + /firmware/manifest.json}"
        "${repositoryRoot + /firmware/partitions-3001.json}"
        "${stockFirmware3001}"
      ]
      (builtins.readFile (repositoryRoot + /scripts/extract-stock));
  };

  stockBoot3001 =
    pkgs.runCommand "CPH2399_14.0.0.3001-boot.img" {
      nativeBuildInputs = [extractStock];
    } ''
      stock_directory="$TMPDIR/stock"
      nord2t-extract-stock --profile boot --output "$stock_directory"
      install -m 0644 "$stock_directory/images/boot.img" "$out"
    '';

  # The exact stock vendor image contains ten MediaTek modules signed by the
  # certificate embedded in its matching stock kernel. Export only that
  # public certificate for offline module verification and for the
  # source-built control kernel's trusted keyring. Both kernel forms are
  # pinned before the fixed offset is used.
  stockModuleSigningCertificate =
    pkgs.runCommand "karen-stock-module-signing-certificate.x509.der" {
      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gzip
        pkgs.mkbootimg-osm0sis
        pkgs.openssl
      ];
    } ''
      mkdir boot
      unpackbootimg -i ${stockBoot3001} -o boot >/dev/null
      mapfile -t kernels < <(
        find boot -maxdepth 1 -type f -name '*boot.img-kernel' -print
      )
      test "''${#kernels[@]}" = 1
      test \
        "$(sha256sum "''${kernels[0]}" | cut -d' ' -f1)" = \
        917716ae774cc32f71d1b7f7962e472ece9e5f82c1676e4362ac90b7219dac10
      gzip -dc "''${kernels[0]}" >stock-Image
      test \
        "$(sha256sum stock-Image | cut -d' ' -f1)" = \
        e506f09c71a7c811e9b63bf063cf605814dc5799358810a87f0b9ff83232de3e
      dd \
        if=stock-Image \
        of="$out" \
        iflag=skip_bytes,count_bytes \
        skip=37325056 \
        count=1346 \
        status=none
      test \
        "$(sha256sum "$out" | cut -d' ' -f1)" = \
        30ee2ffb56cefe69f1c6d0439b7c566fa6121f784ba90d80bfba212404f7000d
      openssl x509 \
        -inform DER \
        -in "$out" \
        -noout \
        -subject \
        -issuer \
        -serial >certificate.txt
      grep -Fxq \
        'subject=CN=Build time autogenerated kernel key' \
        certificate.txt
      grep -Fxq \
        'issuer=CN=Build time autogenerated kernel key' \
        certificate.txt
      grep -Fxq 'serial=9DFB3A7B9EEB1555' certificate.txt
      chmod 0444 "$out"
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
      (builtins.readFile (repositoryRoot + /scripts/stock-root));
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
      builtins.readFile (repositoryRoot + /scripts/stock-unroot)
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
      ownerSignApk
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
      (builtins.readFile (repositoryRoot + /scripts/stock-root-full));
  };

  readLineageSystemFingerprint = pkgs.writeShellApplication {
    name = "nord2t-read-lineage-system-fingerprint";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      e2fsprogs
      erofs-utils
      gnugrep
      gnused
    ];
    text =
      builtins.readFile
      (repositoryRoot + /scripts/read-lineage-system-fingerprint);
  };

  lineageRoot = pkgs.writeShellApplication {
    name = "nord2t-lineage-root";
    runtimeInputs = with pkgs; [
      android-tools
      auditBoot
      auditLineageImages
      coreutils
      erofs-utils
      gawk
      gnugrep
      gnused
      mkbootimg-osm0sis
      readLineageSystemFingerprint
      unzip
    ];
    text = builtins.replaceStrings ["@MAGISK_APK@"] ["${magiskApk}"] (
      builtins.readFile (repositoryRoot + /scripts/lineage-root)
    );
  };

  lineageUnroot = pkgs.writeShellApplication {
    name = "nord2t-lineage-unroot";
    runtimeInputs = with pkgs; [
      android-tools
      auditLineageImages
      coreutils
      erofs-utils
      gawk
      gnugrep
      gnused
    ];
    text = builtins.readFile (repositoryRoot + /scripts/lineage-unroot);
  };

  lineageRootFull = pkgs.writeShellApplication {
    name = "nord2t-lineage-root-full";
    runtimeInputs = with pkgs; [
      android-tools
      auditLineageImages
      coreutils
      erofs-utils
      gawk
      gnugrep
      gnused
      lineageRoot
      ownerSignApk
      readLineageSystemFingerprint
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
      (builtins.readFile (repositoryRoot + /scripts/lineage-root-full));
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
      setools
    ];
    text = builtins.readFile (repositoryRoot + /scripts/audit-boot-image);
  };

  auditKernelModuleAbi = pkgs.writeShellApplication {
    name = "nord2t-audit-kernel-module-abi";
    runtimeInputs = with pkgs; [
      coreutils
      erofs-utils
      gawk
      jq
      kmod
      openssl
    ];
    text =
      builtins.replaceStrings
      ["@PARTITION_MANIFEST@"]
      ["${repositoryRoot + /firmware/partitions-3001.json}"]
      (
        builtins.readFile
        (repositoryRoot + /scripts/audit-kernel-module-abi)
      );
  };

  compareKernelModulePayloads = pkgs.writeShellApplication {
    name = "nord2t-compare-kernel-module-payloads";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      erofs-utils
      findutils
      jq
      kmod
    ];
    text =
      builtins.replaceStrings
      ["@PARTITION_MANIFEST@"]
      ["${repositoryRoot + /firmware/partitions-3001.json}"]
      (
        builtins.readFile
        (repositoryRoot + /scripts/compare-kernel-module-payloads)
      );
  };

  repackControlVendor = pkgs.writeShellApplication {
    name = "nord2t-repack-control-vendor";
    runtimeInputs = with pkgs; [
      android-tools
      attr
      auditKernelModuleAbi
      coreutils
      diffutils
      erofs-utils
      findutils
      gnugrep
      gnused
      jq
      mkbootimg-osm0sis
    ];
    text =
      builtins.replaceStrings
      ["@PARTITION_MANIFEST@"]
      ["${repositoryRoot + /firmware/partitions-3001.json}"]
      (
        builtins.readFile
        (repositoryRoot + /scripts/repack-control-vendor)
      );
  };

  auditLineageImages = pkgs.writeShellApplication {
    name = "nord2t-audit-lineage-images";
    runtimeInputs = with pkgs; [
      android-tools
      auditBoot
      coreutils
      e2fsprogs
      erofs-utils
      extractStock
      findutils
      gawk
      gnugrep
      jq
      kmod
      openssl
    ];
    text =
      builtins.replaceStrings
      [
        "@PARTITION_MANIFEST@"
        "@STOCK_MODULE_CERTIFICATE@"
      ]
      [
        "${repositoryRoot + /firmware/partitions-3001.json}"
        "${stockModuleSigningCertificate}"
      ]
      (builtins.readFile (repositoryRoot + /scripts/audit-lineage-images));
  };

  auditLineageRuntime = pkgs.writeShellApplication {
    name = "nord2t-audit-lineage-runtime";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gawk
      gnugrep
      gnused
    ];
    text = builtins.readFile (repositoryRoot + /scripts/audit-lineage-runtime);
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
    text =
      builtins.replaceStrings
      ["@PARTITION_MANIFEST@"]
      ["${repositoryRoot + /firmware/partitions-3001.json}"]
      (
        builtins.readFile
        (repositoryRoot + /scripts/preflight-lineage-userspace)
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
    text =
      builtins.replaceStrings
      ["@PARTITION_MANIFEST@"]
      ["${repositoryRoot + /firmware/partitions-3001.json}"]
      (builtins.readFile (repositoryRoot + /scripts/lineage-userspace));
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
    text = builtins.readFile (repositoryRoot + /scripts/lineage-keybound-adb);
  };

  rescueControlBoot = pkgs.writeShellApplication {
    name = "nord2t-rescue-control-boot";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gawk
      gnused
    ];
    text = builtins.readFile (repositoryRoot + /scripts/rescue-control-boot);
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
    text = builtins.readFile (repositoryRoot + /scripts/snapshot-device);
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
    text =
      builtins.replaceStrings
      ["@FIRMWARE_MANIFEST@"]
      ["${repositoryRoot + /firmware/manifest.json}"]
      (builtins.readFile (repositoryRoot + /scripts/verify-firmware));
  };
in {
  inherit
    extractStock
    stockBoot3001
    stockFrameworkVintf3001
    stockLineage3001
    stockModuleSigningCertificate
    ;

  public = {
    adb-key-generator = adbKeyGenerator;
    audit-boot = auditBoot;
    audit-kernel-module-abi = auditKernelModuleAbi;
    compare-kernel-module-payloads = compareKernelModulePayloads;
    audit-lineage-images = auditLineageImages;
    audit-lineage-runtime = auditLineageRuntime;
    default = auditLineageRuntime;
    extract-stock = extractStock;
    install-aurora = installAurora;
    kernel-module-owner-build = kernelModuleOwnerBuild;
    kernel-module-owner-sign = kernelModuleOwnerSign;
    kernel-module-sign-file = kernelModuleSignFile;
    kernel-module-signing-key-generator = kernelModuleSigningKeyGenerator;
    lineage-keybound-adb = lineageKeyboundAdb;
    lineage-root = lineageRoot;
    lineage-root-full = lineageRootFull;
    lineage-unroot = lineageUnroot;
    lineage-userspace = lineageUserspace;
    mtkclient-karen = mtkclientKaren;
    owner-sign-apk = ownerSignApk;
    preflight-lineage-userspace = preflightLineageUserspace;
    probe-preloader = probePreloader;
    read-lineage-system-fingerprint = readLineageSystemFingerprint;
    read-gpt = readGpt;
    repack-control-vendor = repackControlVendor;
    rescue-control-boot = rescueControlBoot;
    snapshot = snapshotDevice;
    stock-boot-3001 = stockBoot3001;
    stock-framework-vintf-3001 = stockFrameworkVintf3001;
    stock-lineage-3001 = stockLineage3001;
    stock-restore-3001 = stockRestore3001;
    stock-root = stockRoot;
    stock-root-full = stockRootFull;
    stock-unroot = stockUnroot;
    vector-owner-build-intermediate = vectorOwnerBuildIntermediate;
    vector-owner-sign = vectorOwnerSign;
    vector-signing-key-generator = vectorSigningKeyGenerator;
    verify-firmware = verifyFirmware;
  };
}
