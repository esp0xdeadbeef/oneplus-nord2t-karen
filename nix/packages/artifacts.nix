# SPDX-License-Identifier: MIT
{
  adaway-source,
  hma-apk,
  magisk-apk,
  mindthegapps-14-arm64,
  nixpkgs,
  pkgs,
  shamiko-module,
  stock-firmware-3001,
  system,
  vector-source,
  ...
}: let
  repositoryRoot = ../..;

  auroraStore = pkgs.fetchurl {
    url = "https://f-droid.org/repo/com.aurora.store_75.apk";
    hash = "sha256-xM4N8Luw6Cvk5L19ij4ADwjgRFcYfVYP4so65SlBv0k=";
  };

  mindTheGapps14Arm64 =
    pkgs.runCommand "MindTheGapps-14.0.0-arm64-20250203_200051.zip" {
      nativeBuildInputs = [pkgs.coreutils];
    } ''
      test "$(stat -Lc %s ${mindthegapps-14-arm64})" = 431524182
      test \
        "$(sha256sum ${mindthegapps-14-arm64} | cut -d' ' -f1)" = \
        6e1c3616862ce5b33e2b96074f86ae846eb1351a26a980e1ed140f8a7e7a4fd6
      ln -s ${mindthegapps-14-arm64} "$out"
    '';

  stockFirmware3001 = pkgs.runCommand "CPH2399_14.0.0.3001_OTA.zip" {} ''
    ln -s ${stock-firmware-3001} "$out"
  '';

  # Robotnix's Lineage lock predates three upstream WebView updates. The older
  # 147 arm renderer reproducibly SIGTRAPs on fast.com; 150 survives the same
  # hardware test and retains the upstream certificate.
  lineageWebviewArm64 = pkgs.fetchgit {
    url = "https://github.com/LineageOS/android_external_chromium-webview_prebuilt_arm64.git";
    rev = "aca8d63899707c568d48c412e2c34a8c11c4dd12";
    hash = "sha256-xBjQHGb8+RYzgR08qzA/dEpG0p5G9CnctSGmk5oHMYw=";
    fetchLFS = true;
  };

  magiskApk = pkgs.runCommand "Magisk-v30.7.apk" {} ''
    ln -s ${magisk-apk} "$out"
  '';

  vectorGradleUnwrapped = pkgs.gradle-packages.mkGradle {
    version = "9.3.1";
    hash = "sha256-smbV/2uQ6tptw7IMsJDjcxMC5VOifF0+TfHw12vq/wY=";
    defaultJava = pkgs.jdk21;
  };
  vectorGradle = vectorGradleUnwrapped.wrapped;

  vectorAndroidPkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };
  vectorAndroid = vectorAndroidPkgs.androidenv.composeAndroidPackages {
    platformVersions = ["36"];
    buildToolsVersions = ["36.0.0"];
    includeNDK = true;
    # Upstream requests the NDK 29 rc1 path 29.0.13113456.
    ndkVersions = ["29.0.13113456-rc1"];
    includeCmake = false;
    includeSources = false;
    includeSystemImages = false;
  };
  vectorSigningAndroid = vectorAndroidPkgs.androidenv.composeAndroidPackages {
    platformVersions = [];
    buildToolsVersions = ["36.0.0"];
    includeNDK = false;
    includeCmake = false;
    includeSources = false;
    includeSystemImages = false;
  };

  adawayGradleUnwrapped = pkgs.gradle-packages.mkGradle {
    version = "8.9";
    hash = "sha256-1yXXB7+r1N/clYxiQAOzyArMwD9wN7USLEsdDvFc7Ks=";
    defaultJava = pkgs.jdk17;
  };
  adawayGradle = adawayGradleUnwrapped.wrapped;

  adawayAndroidPkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };
  adawayAndroid = adawayAndroidPkgs.androidenv.composeAndroidPackages {
    platformVersions = [
      "33"
      "34"
    ];
    buildToolsVersions = ["34.0.0"];
    includeNDK = true;
    ndkVersions = ["25.2.9519653"];
    includeCmake = false;
    includeSources = false;
    includeSystemImages = false;
  };

  vectorOwnerCertificateEnvironment =
    builtins.getEnv "KAREN_VECTOR_SIGNING_CERTIFICATE_FILE";
  vectorOwnerCertificate =
    if vectorOwnerCertificateEnvironment == ""
    then null
    else
      builtins.path {
        path = vectorOwnerCertificateEnvironment;
        name = "vector-owner-signing-certificate.x509.der";
      };

  adbPublicKeyEnvironment =
    builtins.getEnv "KAREN_DEBUG_ADB_PUBLIC_KEY_FILE";
  adbPublicKey =
    if adbPublicKeyEnvironment == ""
    then null
    else
      pkgs.runCommand "karen-owner-adbkey.pub" {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gawk
        ];
        source = builtins.path {
          path = adbPublicKeyEnvironment;
          name = "karen-owner-adbkey-source.pub";
        };
      } ''
        test "$(awk 'NF { count++ } END { print count + 0 }' "$source")" = 1
        awk 'NF { print $1; exit }' "$source" |
          base64 --decode >decoded-key
        test "$(stat -c %s decoded-key)" = 524
        install -m 0444 "$source" "$out"
      '';

  mkVectorModule = {
    pname,
    signingCertificate ? null,
  }:
    pkgs.stdenv.mkDerivation (finalAttrs: {
      inherit pname;
      version = "2.0-3021";

      src = vector-source;
      patches = [
        (repositoryRoot + /patches/vector/0001-sepolicy-allow-system-service-native-modules.patch)
        (repositoryRoot + /patches/vector/0002-build-use-pinned-release-metadata.patch)
        (repositoryRoot + /patches/vector/0003-build-accept-public-signing-certificate.patch)
        (repositoryRoot + /patches/vector/0004-build-raise-gradle-daemon-memory.patch)
      ];

      nativeBuildInputs = [
        vectorGradle
        pkgs.cmake
        pkgs.gitMinimal
        pkgs.jdk21
        pkgs.ninja
        pkgs.unzip
        vectorAndroid.androidsdk
      ];

      mitmCache = vectorGradle.fetchDeps {
        pkg = finalAttrs.finalPackage;
        data = repositoryRoot + /gradle/vector-deps.json;
      };

      ANDROID_HOME = "${vectorAndroid.androidsdk}/libexec/android-sdk";
      ANDROID_SDK_ROOT = "${vectorAndroid.androidsdk}/libexec/android-sdk";
      JAVA_HOME = pkgs.jdk21.home;
      gradleBuildTask = ":zygisk:zipRelease";
      gradleUpdateTask = ":zygisk:zipRelease";
      gradleFlags =
        [
          "--no-daemon"
          "-Dorg.gradle.java.home=${pkgs.jdk21.home}"
          "-Pandroid.aapt2FromMavenOverride=${vectorAndroid.androidsdk}/libexec/android-sdk/build-tools/36.0.0/aapt2"
        ]
        ++ pkgs.lib.optional (signingCertificate != null)
        "-PandroidSigningCertificateFile=${signingCertificate}";
      dontUseCmakeConfigure = true;
      doCheck = false;

      installPhase = ''
        runHook preInstall
        mapfile -t modules < <(
          find zygisk/release \
            -maxdepth 1 \
            -type f \
            -name 'Vector-v2.0-3021-Release.zip' \
            -print
        )
        test "''${#modules[@]}" = 1
        unzip -p "''${modules[0]}" sepolicy.rule |
          grep -Fxq 'allow system_server apk_data_file file execute'
        cp "''${modules[0]}" "$out"
        runHook postInstall
      '';
    });

  vectorModule = mkVectorModule {
    pname = "vector-karen-generic";
  };
  vectorOwnerModuleIntermediate =
    if vectorOwnerCertificate == null
    then null
    else
      mkVectorModule {
        pname = "vector-karen-owner-intermediate";
        signingCertificate = vectorOwnerCertificate;
      };

  adawayApk = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "adaway-karen-owner-unsigned";
    version = "6.1.4";
    src = adaway-source;
    nativeBuildInputs = [
      adawayAndroid.androidsdk
      adawayGradle
      pkgs.jdk17
    ];
    mitmCache = adawayGradle.fetchDeps {
      pkg = finalAttrs.finalPackage;
      data = repositoryRoot + /gradle/adaway-deps.json;
      # AGP creates and immediately executes prefab_command while configuring
      # the NDK build. fetchDeps' optional bubblewrap root omits its generated
      # interpreter path; the pure nix-shell still isolates inputs and the
      # final derivation remains sandboxed.
      useBwrap = false;
    };
    ANDROID_HOME = "${adawayAndroid.androidsdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${adawayAndroid.androidsdk}/libexec/android-sdk";
    CONFIG_SHELL = "${pkgs.bash}/bin/sh";
    JAVA_HOME = pkgs.jdk17.home;
    SHELL = "${pkgs.bash}/bin/sh";
    gradleBuildTask = ":app:assembleRelease";
    gradleUpdateTask = ":app:assembleRelease";
    gradleFlags = [
      "--no-daemon"
      "-Dorg.gradle.java.home=${pkgs.jdk17.home}"
      "-Pandroid.aapt2FromMavenOverride=${adawayAndroid.androidsdk}/libexec/android-sdk/build-tools/34.0.0/aapt2"
    ];
    postPatch = ''
      substituteInPlace tcpdump/jni/Android.mk \
        --replace-fail \
        'include jni/stub/Android.mk' \
        'SHELL := ${pkgs.bash}/bin/sh
      include jni/stub/Android.mk'
      substituteInPlace webserver/jni/Android.mk \
        --replace-fail \
        'LOCAL_PATH := $(call my-dir)' \
        'SHELL := ${pkgs.bash}/bin/sh
      LOCAL_PATH := $(call my-dir)'
      patchShebangs tcpdump/jni webserver/jni
    '';
    preConfigure = ''
      export ANDROID_USER_HOME="$PWD/.android-user-home"
      mkdir -p "$ANDROID_USER_HOME"
    '';
    dontUseCmakeConfigure = true;
    doCheck = false;
    installPhase = ''
      runHook preInstall
      mapfile -t apks < <(
        find app/build/outputs/apk/release \
          -maxdepth 1 \
          -type f \
          -name '*-unsigned.apk' \
          -print
      )
      test "''${#apks[@]}" = 1
      cp "''${apks[0]}" "$out"
      runHook postInstall
    '';
  });

  hmaApk = pkgs.runCommand "HMA-V3.8.r499.3a346c0-release.apk" {} ''
    ln -s ${hma-apk} "$out"
  '';
  shamikoModule = pkgs.runCommand "Shamiko-v1.2.5-414-release.zip" {} ''
    ln -s ${shamiko-module} "$out"
  '';
in {
  inherit
    adbPublicKey
    adawayApk
    auroraStore
    hmaApk
    lineageWebviewArm64
    magiskApk
    mindTheGapps14Arm64
    shamikoModule
    stockFirmware3001
    vectorModule
    vectorOwnerModuleIntermediate
    vectorSigningAndroid
    ;

  public =
    {
      adaway-apk = adawayApk;
      aurora-store-apk = auroraStore;
      firmware-3001 = stockFirmware3001;
      hma-apk = hmaApk;
      magisk-apk = magiskApk;
      mindthegapps-14-arm64 = mindTheGapps14Arm64;
      shamiko-module = shamikoModule;
      vector-module = vectorModule;
    }
    // pkgs.lib.optionalAttrs (vectorOwnerModuleIntermediate != null) {
      vector-module-owner-intermediate = vectorOwnerModuleIntermediate;
    };
}
