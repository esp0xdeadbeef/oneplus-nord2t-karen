# SPDX-License-Identifier: MIT
{
  artifacts,
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
      mtkclient
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
      mtkclient
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

  auditLineageImages = pkgs.writeShellApplication {
    name = "nord2t-audit-lineage-images";
    runtimeInputs = with pkgs; [
      android-tools
      auditBoot
      coreutils
      e2fsprogs
      extractStock
      gawk
      gnugrep
      jq
    ];
    text =
      builtins.replaceStrings
      ["@PARTITION_MANIFEST@"]
      ["${repositoryRoot + /firmware/partitions-3001.json}"]
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
    ;

  public = {
    adb-key-generator = adbKeyGenerator;
    audit-boot = auditBoot;
    audit-lineage-images = auditLineageImages;
    audit-lineage-runtime = auditLineageRuntime;
    default = auditLineageRuntime;
    extract-stock = extractStock;
    install-aurora = installAurora;
    lineage-keybound-adb = lineageKeyboundAdb;
    lineage-root = lineageRoot;
    lineage-root-full = lineageRootFull;
    lineage-unroot = lineageUnroot;
    lineage-userspace = lineageUserspace;
    owner-sign-apk = ownerSignApk;
    preflight-lineage-userspace = preflightLineageUserspace;
    probe-preloader = probePreloader;
    read-lineage-system-fingerprint = readLineageSystemFingerprint;
    read-gpt = readGpt;
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
