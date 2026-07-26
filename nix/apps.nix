# SPDX-License-Identifier: MIT
{
  pkgs,
  self,
  system,
}: let
  mkPackageApp = packageName: programName: {
    type = "app";
    program = "${self.packages.${system}.${packageName}}/bin/${programName}";
  };

  packageApps = pkgs.lib.mapAttrs mkPackageApp {
    adb-key-generator = "nord2t-adb-key-generator";
    android-fhs = "nord2t-android-fhs";
    audit-boot = "nord2t-audit-boot";
    audit-lineage-images = "nord2t-audit-lineage-images";
    audit-lineage-runtime = "nord2t-audit-lineage-runtime";
    extract-stock = "nord2t-extract-stock";
    install-aurora = "nord2t-install-aurora";
    lineage-keybound-adb = "nord2t-lineage-keybound-adb";
    lineage-root = "nord2t-lineage-root";
    lineage-root-full = "nord2t-lineage-root-full";
    lineage-unroot = "nord2t-lineage-unroot";
    lineage-userspace = "nord2t-lineage-userspace";
    owner-sign-apk = "nord2t-owner-sign-apk";
    preflight-lineage-userspace = "nord2t-preflight-lineage-userspace";
    probe-preloader = "nord2t-probe-preloader";
    read-gpt = "nord2t-read-gpt";
    snapshot = "nord2t-snapshot";
    stock-root = "nord2t-stock-root";
    stock-root-full = "nord2t-stock-root-full";
    stock-unroot = "nord2t-stock-unroot";
    vector-owner-build-intermediate = "nord2t-vector-owner-build-intermediate";
    vector-owner-sign = "nord2t-vector-owner-sign";
    vector-signing-key-generator = "nord2t-vector-signing-key-generator";
    verify-firmware = "nord2t-verify-firmware";
  };

  mkArtifactApp = {
    artifact,
    defaultDirectory,
    name,
  }: let
    runner = pkgs.writeShellApplication {
      name = "nord2t-export-${name}";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        if (( $# > 1 )); then
          echo "Usage: nord2t-export-${name} [OUTPUT_DIRECTORY]" >&2
          exit 2
        fi

        destination="''${1:-$PWD/${defaultDirectory}}"
        if [[ -e "$destination" || -L "$destination" ]]; then
          echo "Refusing to overwrite existing output: $destination" >&2
          exit 1
        fi

        parent="$(dirname -- "$destination")"
        basename="$(basename -- "$destination")"
        mkdir -p -- "$parent"
        temporary="$(mktemp -d --tmpdir="$parent" ".''${basename}.tmp.XXXXXX")"
        cleanup() {
          rm -rf -- "$temporary"
        }
        trap cleanup EXIT

        cp -a --reflink=auto ${artifact}/. "$temporary/"
        chmod -R u+w "$temporary"
        mv -T -- "$temporary" "$destination"
        trap - EXIT
        echo "Exported ${name} to $destination"
      '';
    };
  in {
    type = "app";
    program = "${runner}/bin/nord2t-export-${name}";
  };

  imageApps =
    pkgs.lib.optionalAttrs (system == "x86_64-linux") {
      karen-bootimage = mkArtifactApp {
        artifact = self.packages.${system}.karen-bootimage;
        defaultDirectory = "result-karen-bootimage";
        name = "karen-bootimage";
      };
      karen-device-tree = mkArtifactApp {
        artifact = self.packages.${system}.karen-device-tree;
        defaultDirectory = "result-karen-device-tree";
        name = "karen-device-tree";
      };
      karen-full-images = mkArtifactApp {
        artifact = self.packages.${system}.karen-full-images;
        defaultDirectory = "result-karen-full-images";
        name = "karen-full-images";
      };
      karen-source-kernel-bootimage = mkArtifactApp {
        artifact = self.packages.${system}.karen-source-kernel-bootimage;
        defaultDirectory = "result-karen-source-kernel-bootimage";
        name = "karen-source-kernel-bootimage";
      };
      karen-source-kernel-full-images = mkArtifactApp {
        artifact = self.packages.${system}.karen-source-kernel-full-images;
        defaultDirectory = "result-karen-source-kernel-full-images";
        name = "karen-source-kernel-full-images";
      };
      karen-source-kernel-full-images-cached = mkArtifactApp {
        artifact =
          self.packages.${system}.karen-source-kernel-full-images-cached;
        defaultDirectory = "result-karen-source-kernel-full-images-cached";
        name = "karen-source-kernel-full-images-cached";
      };
      nixos-kexec-initramfs = mkArtifactApp {
        artifact = self.packages.${system}.nixos-kexec-initramfs;
        defaultDirectory = "result-nixos-kexec-initramfs";
        name = "nixos-kexec-initramfs";
      };
    }
    // pkgs.lib.optionalAttrs (
      system
      == "x86_64-linux"
      && self.packages.${system} ? karen-source-kernel-keybound-full-images
    ) {
      karen-source-kernel-keybound-bootimage = mkArtifactApp {
        artifact =
          self.packages.${system}.karen-source-kernel-keybound-bootimage;
        defaultDirectory = "result-karen-source-kernel-keybound-bootimage";
        name = "karen-source-kernel-keybound-bootimage";
      };
      karen-source-kernel-keybound-full-images = mkArtifactApp {
        artifact =
          self.packages.${system}.karen-source-kernel-keybound-full-images;
        defaultDirectory = "result-karen-source-kernel-keybound-full-images";
        name = "karen-source-kernel-keybound-full-images";
      };
      karen-source-kernel-keybound-full-images-cached = mkArtifactApp {
        artifact =
          self.packages.${system}.karen-source-kernel-keybound-full-images-cached;
        defaultDirectory = "result-karen-source-kernel-keybound-full-images-cached";
        name = "karen-source-kernel-keybound-full-images-cached";
      };
    };
in
  packageApps
  // imageApps
  // {
    default = self.apps.${system}.audit-lineage-runtime;
  }
