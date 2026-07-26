# SPDX-License-Identifier: MIT
{
  deviceTools,
  oneplus-kernel-modules,
  oneplus-kernel-source,
  pkgs,
  system,
  ...
}: let
  repositoryRoot = ../../..;

  inherit (deviceTools) stockModuleSigningCertificate;

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
      nativeBuildInputs = [
        pkgs.openssl
        pkgs.patch
      ];
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
      openssl x509 \
        -inform DER \
        -in ${stockModuleSigningCertificate} \
        -out "$out/certs/karen-stock-module-signing.x509"
      grep -Fxq -- \
        '-----BEGIN CERTIFICATE-----' \
        "$out/certs/karen-stock-module-signing.x509"
      chmod 0444 "$out/certs/karen-stock-module-signing.x509"
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
      cat >>"$control_defconfig" <<'EOF'
      CONFIG_SYSTEM_TRUSTED_KEYS="certs/karen-stock-module-signing.x509"
      EOF
      grep -Fxq 'CONFIG_KEXEC=y' "$control_defconfig"
      grep -Fxq \
        'CONFIG_SYSTEM_TRUSTED_KEYS="certs/karen-stock-module-signing.x509"' \
        "$control_defconfig"
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

  nixosKexecInitramfs =
    if system == "x86_64-linux"
    then let
      callbackAddress = "192.168.97.1";
      callbackPort = 9001;
      deviceAddress = "192.168.97.2";
      targetBusybox = pkgs.pkgsCross.aarch64-multiplatform.pkgsStatic.busybox.override {
        extraConfig = ''
          CONFIG_NC y
          CONFIG_NC_SERVER y
          CONFIG_NC_EXTRA y
          CONFIG_NC_110_COMPAT y
        '';
      };
      osRelease = pkgs.writeText "karen-nixos-kexec-os-release" ''
        NAME="NixOS"
        ID=nixos
        PRETTY_NAME="NixOS Karen kexec stage 1"
        VARIANT_ID=karen-kexec-stage1
      '';
      callbackShell = pkgs.writeTextFile {
        name = "karen-nixos-callback-shell";
        executable = true;
        text = ''
          #!/bin/sh
          printf 'NIXOS_KEXEC_READY\n'
          cat /etc/os-release
          uname -a
          exec /bin/sh -i
        '';
      };
      init = pkgs.writeTextFile {
        name = "karen-nixos-kexec-init";
        executable = true;
        text = ''
          #!/bin/sh

          export PATH=/bin:/sbin

          mkdir -p /dev /proc /run /sys /tmp
          if [ ! -c /dev/null ]; then
            mount -t devtmpfs devtmpfs /dev
          fi
          mount -t proc proc /proc
          mount -t sysfs sysfs /sys
          mount -t tmpfs tmpfs /run
          mount -t tmpfs tmpfs /tmp
          hostname karen-nixos-kexec

          log() {
            printf 'karen-nixos: %s\n' "$*" >/dev/kmsg
            printf 'karen-nixos: %s\n' "$*"
          }

          log 'entered NixOS kexec stage 1'

          callback_enabled=false
          for argument in $(cat /proc/cmdline); do
            if [ "$argument" = karen.nixos.callback=1 ]; then
              callback_enabled=true
              break
            fi
          done

          if [ "$callback_enabled" != true ]; then
            log 'callback disabled; add karen.nixos.callback=1 explicitly'
            exec /bin/sh -i
          fi

          mkdir -p /sys/kernel/config
          mount -t configfs configfs /sys/kernel/config
          gadget=/sys/kernel/config/usb_gadget/karen-nixos
          mkdir -p \
            "$gadget/configs/c.1/strings/0x409" \
            "$gadget/functions/rndis.usb0" \
            "$gadget/strings/0x409"
          printf 0x18d1 >"$gadget/idVendor"
          printf 0x4ee7 >"$gadget/idProduct"
          printf 0x0200 >"$gadget/bcdUSB"
          printf 0x0100 >"$gadget/bcdDevice"
          printf 'NixOS' >"$gadget/strings/0x409/manufacturer"
          printf 'Karen kexec stage 1' >"$gadget/strings/0x409/product"
          printf 'karen-nixos-kexec' >"$gadget/strings/0x409/serialnumber"
          printf 'RNDIS callback' >"$gadget/configs/c.1/strings/0x409/configuration"
          printf 250 >"$gadget/configs/c.1/MaxPower"
          printf '02:4b:41:52:45:4e' \
            >"$gadget/functions/rndis.usb0/host_addr"
          printf '02:4b:41:52:45:4f' \
            >"$gadget/functions/rndis.usb0/dev_addr"
          ln -s \
            "$gadget/functions/rndis.usb0" \
            "$gadget/configs/c.1/rndis.usb0"

          udc=
          attempts=0
          while [ "$attempts" -lt 100 ]; do
            for candidate in /sys/class/udc/*; do
              if [ -e "$candidate" ]; then
                udc="''${candidate##*/}"
                break
              fi
            done
            [ -n "$udc" ] && break
            attempts=$((attempts + 1))
            sleep 0.1
          done
          if [ -z "$udc" ]; then
            log 'no USB device controller appeared'
            exec /bin/sh -i
          fi
          printf '%s' "$udc" >"$gadget/UDC"
          log "bound RNDIS gadget to $udc"

          interface=
          attempts=0
          while [ "$attempts" -lt 100 ]; do
            for candidate in usb0 rndis0; do
              if ip link show "$candidate" >/dev/null 2>&1; then
                interface="$candidate"
                break
              fi
            done
            [ -n "$interface" ] && break
            attempts=$((attempts + 1))
            sleep 0.1
          done
          if [ -z "$interface" ]; then
            log 'RNDIS network interface did not appear'
            exec /bin/sh -i
          fi

          ifconfig "$interface" ${deviceAddress} netmask 255.255.255.252 up
          log "configured $interface as ${deviceAddress}/30"

          while :; do
            log 'attempting the USB-only callback'
            nc -w 30 \
              ${callbackAddress} \
              ${toString callbackPort} \
              -e /karen-nixos-callback-shell
            sleep 2
          done
        '';
      };
      rawInitramfs = pkgs.makeInitrd {
        name = "karen-nixos-kexec-stage1-initramfs";
        compressor = "gzip";
        contents = [
          {
            object = init;
            symlink = "/init";
          }
          {
            object = callbackShell;
            symlink = "/karen-nixos-callback-shell";
          }
          {
            object = "${targetBusybox}/bin";
            symlink = "/bin";
          }
          {
            object = "${targetBusybox}/sbin";
            symlink = "/sbin";
          }
          {
            object = osRelease;
            symlink = "/etc/os-release";
          }
        ];
      };
    in
      pkgs.runCommand "karen-nixos-kexec-stage1" {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.cpio
          pkgs.file
          pkgs.gzip
          pkgs.jq
        ];
      } ''
        mkdir -p "$out"
        install -m 0644 ${rawInitramfs}/initrd "$out/initrd.gz"
        file "$out/initrd.gz" | grep -Fq 'gzip compressed data'
        gzip -dc "$out/initrd.gz" >initrd.cpio
        cpio -it <initrd.cpio >contents
        grep -Fxq init contents
        grep -Fxq karen-nixos-callback-shell contents
        grep -Fxq etc/os-release contents
        jq -n \
          --arg architecture aarch64-linux \
          --arg callback_address ${callbackAddress} \
          --argjson callback_port ${toString callbackPort} \
          --arg device_address ${deviceAddress} \
          --arg sha256 "$(sha256sum "$out/initrd.gz" | cut -d' ' -f1)" \
          --argjson size "$(stat -c %s "$out/initrd.gz")" \
          '{
            architecture: $architecture,
            callback: {
              activation: "karen.nixos.callback=1",
              address: $callback_address,
              port: $callback_port,
              transport: "USB RNDIS only"
            },
            device_address: $device_address,
            initramfs: {
              file: "initrd.gz",
              sha256: $sha256,
              size: $size
            },
            persistent_writes: false,
            stage: "NixOS kexec stage 1"
          }' >"$out/manifest.json"
      ''
    else null;
in {
  inherit
    nixosKexecInitramfs
    oneplusControlKernelModules
    oneplusControlKernelSource
    stockModuleSigningCertificate
    ;

  # A native NixOS kernel package is deliberately absent until the upstream
  # MT6893 port exists. These are only the KEXEC-capable Android bootstrap
  # trees used to reach that future kernel.
  public =
    {
      karen-stock-module-signing-certificate =
        stockModuleSigningCertificate;
    }
    // pkgs.lib.optionalAttrs (nixosKexecInitramfs != null) {
      nixos-kexec-initramfs = nixosKexecInitramfs;
    };
}
