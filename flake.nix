# SPDX-License-Identifier: MIT
{
  description = "OnePlus Nord 2T (CPH2399/karen) recovery and LineageOS tooling";

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

  outputs = {
    adaway-source,
    hma-apk,
    self,
    magisk-apk,
    mindthegapps-14-arm64,
    nixpkgs,
    oneplus-kernel-modules,
    oneplus-kernel-source,
    robotnix,
    shamiko-module,
    stock-firmware-3001,
    vector-source,
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

        # Robotnix's Lineage lock predates three upstream WebView updates.
        # The older 147 arm renderer reproducibly SIGTRAPs on fast.com; 150
        # survives the same hardware test and retains the upstream certificate.
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

        mkVectorModule = {
          pname,
          signingCertificate ? null,
        }:
          pkgs.stdenv.mkDerivation (finalAttrs: {
            inherit pname;
            version = "2.0-3021";

            src = vector-source;
            patches = [
              ./patches/vector/0001-sepolicy-allow-system-service-native-modules.patch
              ./patches/vector/0002-build-use-pinned-release-metadata.patch
              ./patches/vector/0003-build-accept-public-signing-certificate.patch
              ./patches/vector/0004-build-raise-gradle-daemon-memory.patch
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
              data = ./gradle/vector-deps.json;
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
            data = ./gradle/adaway-deps.json;
            # AGP creates and immediately executes prefab_command while
            # configuring the NDK build. fetchDeps' optional bubblewrap root
            # omits its generated interpreter path; the pure nix-shell still
            # isolates inputs and the final derivation remains sandboxed.
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

        oneplusKernelSource = pkgs.runCommand "oneplus-karen-kernel-source" {} ''
          ln -s ${oneplus-kernel-source} "$out"
        '';

        oneplusControlKernelSource =
          pkgs.runCommand "oneplus-karen-control-kernel-source" {
            nativeBuildInputs = [pkgs.patch];
          } ''
            cp --no-preserve=ownership --reflink=auto -r \
              ${oneplus-kernel-source} "$out"
            chmod -R u+w "$out"
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0001-clang-fix-control-kernel-errors.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0003-clang-fix-control-kernel-warnings.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0005-clang-tolerate-legacy-vendor-warnings.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0006-clang-fix-control-kernel-types.patch}
            substituteInPlace "$out/net/oplus_nwpower/oplus_nwpower.c" \
              --replace-fail \
              'static void nwpower_unsl_blacklist_reject() {' \
              'static void nwpower_unsl_blacklist_reject(void) {' \
              --replace-fail \
              'extern void oplus_match_modem_wakeup() {' \
              'extern void oplus_match_modem_wakeup(void) {' \
              --replace-fail \
              'extern void oplus_match_wlan_wakeup() {' \
              'extern void oplus_match_wlan_wakeup(void) {' \
              --replace-fail \
              'extern void oplus_ipa_schedule_work() {' \
              'extern void oplus_ipa_schedule_work(void) {' \
              --replace-fail \
              'static void nwpower_unsl_app_wakeup()' \
              'static void nwpower_unsl_app_wakeup(void)' \
              --replace-fail \
              'static void nwpower_hook_on() {' \
              'static void nwpower_hook_on(void) {' \
              --replace-fail \
              'static void nwpower_unsl_mdaci() {' \
              'static void nwpower_unsl_mdaci(void) {'
            substituteInPlace \
              "$out/drivers/misc/oplus_misc_healthinfo/oplus_misc_healthinfo.c" \
              --replace-fail \
              'static oplus_misc_healthinfo_parse_dt(' \
              'static int oplus_misc_healthinfo_parse_dt('
            mapfile -t eeprom_sensor_sources < <(
              grep -RIl \
                --include='*.c' \
                '^extern Eeprom_DistortionParamsRead' \
                "$out/drivers/misc/mediatek/imgsensor"
            )
            test "''${#eeprom_sensor_sources[@]}" -gt 0
            for sensor_source in "''${eeprom_sensor_sources[@]}"; do
              substituteInPlace "$sensor_source" \
                --replace-fail \
                'extern Eeprom_DistortionParamsRead(' \
                'extern void Eeprom_DistortionParamsRead('
            done
            control_defconfig="$out/arch/arm64/configs/k6893v1_64_k419_ab_nixos_control_defconfig"
            cp \
              "$out/arch/arm64/configs/k6893v1_64_k419_ab_defconfig" \
              "$control_defconfig"
            cat ${./nixos/families/mt6893/kernel/nixos-control.config} \
              >>"$control_defconfig"
            grep -Fxq 'CONFIG_KEXEC=y' "$control_defconfig"
          '';

        oneplusControlKernelModules =
          pkgs.runCommand "oneplus-karen-control-kernel-modules" {
            nativeBuildInputs = [pkgs.patch];
          } ''
            cp --no-preserve=ownership --reflink=auto -r \
              ${oneplus-kernel-modules} "$out"
            chmod -R u+w "$out"
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0002-oplus-fix-clang-strict-prototypes.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0004-oplus-fix-control-kernel-warnings.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0007-oplus-fix-lineage-kernel-include-paths.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0008-oplus-fix-control-kernel-types.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0009-oplus-fix-vooc-upload-type.patch}
            patch --batch --forward --fuzz=0 -d "$out" -p1 \
              <${./nixos/patches/kernel/0010-oplus-fix-debug-boolean-types.patch}
            substituteInPlace \
              "$out/vendor/oplus/kernel/charger/charger_ic/oplus_usbtemp.c" \
              --replace-fail \
              'static current_read_count = 0;' \
              'static int current_read_count = 0;'
            substituteInPlace \
              "$out/vendor/oplus/kernel/charger/vooc_ic/oplus_stm8s.c" \
              --replace-fail \
              'static stm8s_parse_fw_from_array(' \
              'static int stm8s_parse_fw_from_array('
            substituteInPlace \
              "$out/vendor/oplus/kernel/secureguard/rootguard/oplus_guard_general.c" \
              --replace-fail \
              'static void __exit boot_state_exit()' \
              'static void __exit boot_state_exit(void)'
          '';

        oneplusKernelModules = pkgs.runCommand "oneplus-karen-kernel-modules" {} ''
          ln -s ${oneplus-kernel-modules}/vendor/mediatek/kernel_modules "$out"
        '';

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
          text = builtins.readFile ./scripts/adb-key-generator;
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
          text = builtins.readFile ./scripts/vector-signing-key-generator;
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
          text = builtins.readFile ./scripts/vector-owner-build-intermediate;
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
            (builtins.readFile ./scripts/vector-owner-sign);
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
            (builtins.readFile ./scripts/owner-sign-apk);
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
            builtins.readFile ./scripts/install-aurora
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
            (builtins.readFile ./scripts/stock-root-full);
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
          text = builtins.readFile ./scripts/read-lineage-system-fingerprint;
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
            builtins.readFile ./scripts/lineage-root
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
          text = builtins.readFile ./scripts/lineage-unroot;
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
            (builtins.readFile ./scripts/lineage-root-full);
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
          text = builtins.readFile ./scripts/audit-boot-image;
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
          text = builtins.replaceStrings ["@PARTITION_MANIFEST@"] ["${./firmware/partitions-3001.json}"] (
            builtins.readFile ./scripts/audit-lineage-images
          );
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
          text = builtins.readFile ./scripts/audit-lineage-runtime;
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
                webviewSource = lineageWebviewArm64;
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
              import ./lineage/robotnix-karen.nix {
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
                effective_config="$ANDROID_PRODUCT_OUT/obj/KERNEL_OBJ/.config"
                grep -Fxq 'CONFIG_KEXEC=y' "$effective_config"
                mkdir -p "$out"
                cp --reflink=auto "$ANDROID_PRODUCT_OUT/boot.img" "$out/boot.img"
                cp --reflink=auto "$ANDROID_PRODUCT_OUT/kernel" "$out/kernel"
                cp --reflink=auto "$effective_config" "$out/kernel.config"
              '';
            }
          else null;
      in
        {
          adb-key-generator = adbKeyGenerator;
          android-fhs = androidFhs;
          adaway-apk = adawayApk;
          audit-boot = auditBoot;
          audit-lineage-images = auditLineageImages;
          audit-lineage-runtime = auditLineageRuntime;
          aurora-store-apk = auroraStore;
          default = auditLineageRuntime;
          extract-stock = extractStock;
          firmware-3001 = stockFirmware3001;
          hma-apk = hmaApk;
          install-aurora = installAurora;
          lineage-keybound-adb = lineageKeyboundAdb;
          lineage-root = lineageRoot;
          lineage-root-full = lineageRootFull;
          lineage-unroot = lineageUnroot;
          lineage-userspace = lineageUserspace;
          magisk-apk = magiskApk;
          mindthegapps-14-arm64 = mindTheGapps14Arm64;
          oneplus-kernel-modules = oneplusKernelModules;
          oneplus-kernel-source = oneplusKernelSource;
          owner-sign-apk = ownerSignApk;
          preflight-lineage-userspace = preflightLineageUserspace;
          probe-preloader = probePreloader;
          read-lineage-system-fingerprint = readLineageSystemFingerprint;
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
          vector-owner-build-intermediate = vectorOwnerBuildIntermediate;
          vector-owner-sign = vectorOwnerSign;
          vector-signing-key-generator = vectorSigningKeyGenerator;
          verify-firmware = verifyFirmware;
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          karen-bootimage = karenBootimage;
          karen-device-tree = karenDeviceTree;
          karen-full-images = karenFullImages;
          karen-source-kernel-bootimage = karenSourceKernelBootimage;
        }
        // pkgs.lib.optionalAttrs (vectorOwnerModuleIntermediate != null) {
          vector-module-owner-intermediate = vectorOwnerModuleIntermediate;
        }
    );

    apps = eachSystem (
      {system, ...}: {
        default = self.apps.${system}.audit-lineage-runtime;
        adb-key-generator = {
          type = "app";
          program = "${self.packages.${system}.adb-key-generator}/bin/nord2t-adb-key-generator";
        };
        vector-signing-key-generator = {
          type = "app";
          program = "${self.packages.${system}.vector-signing-key-generator}/bin/nord2t-vector-signing-key-generator";
        };
        vector-owner-build-intermediate = {
          type = "app";
          program = "${self.packages.${system}.vector-owner-build-intermediate}/bin/nord2t-vector-owner-build-intermediate";
        };
        vector-owner-sign = {
          type = "app";
          program = "${self.packages.${system}.vector-owner-sign}/bin/nord2t-vector-owner-sign";
        };
        android-fhs = {
          type = "app";
          program = "${self.packages.${system}.android-fhs}/bin/nord2t-android-fhs";
        };
        extract-stock = {
          type = "app";
          program = "${self.packages.${system}.extract-stock}/bin/nord2t-extract-stock";
        };
        install-aurora = {
          type = "app";
          program = "${self.packages.${system}.install-aurora}/bin/nord2t-install-aurora";
        };
        lineage-userspace = {
          type = "app";
          program = "${self.packages.${system}.lineage-userspace}/bin/nord2t-lineage-userspace";
        };
        lineage-keybound-adb = {
          type = "app";
          program = "${self.packages.${system}.lineage-keybound-adb}/bin/nord2t-lineage-keybound-adb";
        };
        lineage-root = {
          type = "app";
          program = "${self.packages.${system}.lineage-root}/bin/nord2t-lineage-root";
        };
        lineage-root-full = {
          type = "app";
          program = "${self.packages.${system}.lineage-root-full}/bin/nord2t-lineage-root-full";
        };
        lineage-unroot = {
          type = "app";
          program = "${self.packages.${system}.lineage-unroot}/bin/nord2t-lineage-unroot";
        };
        audit-boot = {
          type = "app";
          program = "${self.packages.${system}.audit-boot}/bin/nord2t-audit-boot";
        };
        audit-lineage-images = {
          type = "app";
          program = "${self.packages.${system}.audit-lineage-images}/bin/nord2t-audit-lineage-images";
        };
        audit-lineage-runtime = {
          type = "app";
          program = "${self.packages.${system}.audit-lineage-runtime}/bin/nord2t-audit-lineage-runtime";
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
        owner-sign-apk = {
          type = "app";
          program = "${self.packages.${system}.owner-sign-apk}/bin/nord2t-owner-sign-apk";
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
          adb-key-generator
          audit-boot
          audit-lineage-images
          audit-lineage-runtime
          extract-stock
          install-aurora
          lineage-keybound-adb
          lineage-root
          lineage-root-full
          lineage-unroot
          lineage-userspace
          owner-sign-apk
          preflight-lineage-userspace
          probe-preloader
          read-gpt
          snapshot
          vector-owner-build-intermediate
          vector-owner-sign
          vector-signing-key-generator
          verify-firmware
          ;

        adb-key-generator-test =
          pkgs.runCommand "nord2t-adb-key-generator-test" {
            nativeBuildInputs = with pkgs; [
              age
              android-tools
              bash
              coreutils
              gnugrep
              gnused
              sops
            ];
            src = ./.;
          } ''
            bash "$src"/tests/adb-key-generator.sh
            touch "$out"
          '';

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
              pkgs.jq
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
            age
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
            sops
          ];
        };
      }
    );
  };
}
