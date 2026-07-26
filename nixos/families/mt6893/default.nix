# SPDX-License-Identifier: MIT
{
  name = "mt6893";
  architecture = "aarch64";

  bootstrapKernel = {
    version = "4.19.191";
    format = "Image.gz";
    policy = "byte-identical-stock";
    source = {
      owner = "OnePlusOSS";
      repository = "android_kernel_oneplus_mt6893";
      revision = "a5cdca1a88dc328a44dee724193830254fc551da";
    };
    modules = {
      owner = "OnePlusOSS";
      repository = "android_vendor_mediatek_kernel_modules_mt6893";
      revision = "a198b1d0e4ca41cf48d62793e65a9484ad833312";
    };
    effectiveStockConfig = {
      embedded = true;
      kexec = false;
      nixosControlFragment = ./kernel/nixos-control.config;
    };
  };

  deviceTree = {
    inputPolicy = "byte-identical-stock";
    transformation = "source-patch-recompile";
    inPlaceBinaryPatching = false;
    applyBootloaderDtboBeforeKexec = "unresolved";
  };

  bringup = {
    firstTransport = "usb-gadget-network";
    firstUserspace = "authenticated-headless-stage-1";
    kexecPrerequisite = "source-built-4.19-control-kernel";
    persistentWritesAllowed = false;
    compatibilityContainerEnabled = false;
  };
}
