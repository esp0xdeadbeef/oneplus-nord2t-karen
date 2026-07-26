# SPDX-License-Identifier: MIT
{
  oneplus-kernel-modules,
  oneplus-kernel-source,
  pkgs,
  ...
}: let
  repositoryRoot = ../../..;

  # OnePlus published the MT6893 DWS hardware descriptions but omitted
  # MediaTek's generated cust.dtsi outputs and DCT generator. The community
  # Lineage 21 kernel retained the generated GPL-2.0 files. The control source
  # verifies that the four corresponding DWS inputs are byte-identical before
  # making these outputs available.
  mtkDctGenerated = {
    k6893v1_64_k419 = pkgs.fetchurl {
      name = "k6893v1_64_k419-cust.dtsi";
      url = "https://raw.githubusercontent.com/mt6893-development/android_kernel_oplus_mt6893/1dfa6bf0946e631d4845570d934323fbd92ad283/arch/arm64/boot/dts/k6893v1_64_k419/cust.dtsi";
      hash = "sha256-dF+3AIChrFIwiYycTt8yRI2O1ML9hzC49lRVjgIVbQ0=";
    };
    oplus6893_21127 = pkgs.fetchurl {
      name = "oplus6893_21127-cust.dtsi";
      url = "https://raw.githubusercontent.com/mt6893-development/android_kernel_oplus_mt6893/1dfa6bf0946e631d4845570d934323fbd92ad283/arch/arm64/boot/dts/oplus6893_21127/cust.dtsi";
      hash = "sha256-W8CoWdRsrzX/QplNaTe/pTDc3XqNfFndZNr6tsEOkVs=";
    };
    oplus6893_21881 = pkgs.fetchurl {
      name = "oplus6893_21881-cust.dtsi";
      url = "https://raw.githubusercontent.com/mt6893-development/android_kernel_oplus_mt6893/1dfa6bf0946e631d4845570d934323fbd92ad283/arch/arm64/boot/dts/oplus6893_21881/cust.dtsi";
      hash = "sha256-M3pIpBnt52WO0xjgQKzhG4tej8B8M5h+8/YzRjJO1MU=";
    };
    oplus6893_21305 = pkgs.fetchurl {
      name = "oplus6893_21305-cust.dtsi";
      url = "https://raw.githubusercontent.com/mt6893-development/android_kernel_oplus_mt6893/1dfa6bf0946e631d4845570d934323fbd92ad283/arch/arm64/boot/dts/oplus6893_21305/cust.dtsi";
      hash = "sha256-mZO5lhMLInYdJOM78ZMvxpHvQprydNP1VI+WcJmsQdc=";
    };
  };

  oneplusControlKernelSource =
    pkgs.runCommand "oneplus-karen-control-kernel-source" {
      nativeBuildInputs = [pkgs.patch];
    } ''
      cp --no-preserve=ownership --reflink=auto -r \
        ${oneplus-kernel-source} "$out"
      chmod -R u+w "$out"
      dws_directory="$out/drivers/misc/mediatek/dws/mt6885"
      printf '%s  %s\n' \
        a5e55198fe8a90e8046b21f5e984d52e81a5075ff2bf5520fbb3a4ec8674ec61 \
        "$dws_directory/k6893v1_64_k419.dws" \
        a54453616389c50f7ea1c6157a3e0726f20934142b544772915f771689ebd4d7 \
        "$dws_directory/oplus6893_21127.dws" \
        16299a75f3b0618a6bd63f75269bc8c73013766ca7b1338030c985fcc6bb30ae \
        "$dws_directory/oplus6893_21881.dws" \
        fc4f2284f804f92f8bafb619167bf17d9f3b00dd25099394540f6b0435ddf14a \
        "$dws_directory/oplus6893_21305.dws" |
        sha256sum --check --strict
      install -D -m 0644 \
        ${mtkDctGenerated.k6893v1_64_k419} \
        "$out/arch/arm64/boot/dts/k6893v1_64_k419/cust.dtsi"
      install -D -m 0644 \
        ${mtkDctGenerated.oplus6893_21127} \
        "$out/arch/arm64/boot/dts/oplus6893_21127/cust.dtsi"
      install -D -m 0644 \
        ${mtkDctGenerated.oplus6893_21881} \
        "$out/arch/arm64/boot/dts/oplus6893_21881/cust.dtsi"
      install -D -m 0644 \
        ${mtkDctGenerated.oplus6893_21305} \
        "$out/arch/arm64/boot/dts/oplus6893_21305/cust.dtsi"
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0001-clang-fix-control-kernel-errors.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0003-clang-fix-control-kernel-warnings.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0005-clang-tolerate-legacy-vendor-warnings.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0006-clang-fix-control-kernel-types.patch}
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
      cat \
        ${repositoryRoot + /nixos/families/mt6893/kernel/nixos-control.config} \
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
        <${repositoryRoot + /nixos/patches/kernel/0002-oplus-fix-clang-strict-prototypes.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0004-oplus-fix-control-kernel-warnings.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0007-oplus-fix-lineage-kernel-include-paths.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0008-oplus-fix-control-kernel-types.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0009-oplus-fix-vooc-upload-type.patch}
      patch --batch --forward --fuzz=0 -d "$out" -p1 \
        <${repositoryRoot + /nixos/patches/kernel/0010-oplus-fix-debug-boolean-types.patch}
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
in {
  inherit
    oneplusControlKernelModules
    oneplusControlKernelSource
    ;

  # A native NixOS kernel package is deliberately absent until the upstream
  # MT6893 port exists. These are only the KEXEC-capable Android bootstrap
  # trees used to reach that future kernel.
  public = {};
}
