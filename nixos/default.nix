# SPDX-License-Identifier: MIT
let
  repository = builtins.getFlake (toString ../.);
  system = builtins.currentSystem;
  pkgs = import repository.inputs.nixpkgs {inherit system;};
  metadata = import ./metadata.nix;
  mkDtbWorkspace = pkgs.callPackage ./lib/mk-dtb-workspace.nix {};
  mkKernelConfigAudit = pkgs.callPackage ./lib/mk-kernel-config-audit.nix {};
  stockDeviceTree = repository.packages.${system}.karen-device-tree;
  oneplusKernelSource = repository.packages.${system}.oneplus-kernel-source;
  dtbPatchDirectory = ./patches/dtb;
  dtbPatchEntries = builtins.readDir dtbPatchDirectory;
  dtbPatchNames = builtins.filter (
    name:
      dtbPatchEntries.${name}
      == "regular"
      && builtins.match ".*\\.patch" name != null
  ) (builtins.attrNames dtbPatchEntries);
  dtbPatches = map (name: dtbPatchDirectory + "/${name}") dtbPatchNames;
in {
  inherit metadata;

  karenDtbBaseline = mkDtbWorkspace {
    name = "karen-stock-dtb-baseline";
    inputDtb = "${stockDeviceTree}/prebuilt/dtbs/karen.dtb";
    expectedInputSha256 = metadata.device.stock.dtb.sha256;
  };

  karenDtbPatched = mkDtbWorkspace {
    name = "karen-patched-dtb";
    inputDtb = "${stockDeviceTree}/prebuilt/dtbs/karen.dtb";
    expectedInputSha256 = metadata.device.stock.dtb.sha256;
    patches = dtbPatches;
  };

  karenKernelConfigAudit = mkKernelConfigAudit {
    expectedKernelSha256 = metadata.device.stock.kernel.sha256;
    kernelImage = "${stockDeviceTree}/prebuilt/kernel";
    kernelSource = oneplusKernelSource;
  };
}
