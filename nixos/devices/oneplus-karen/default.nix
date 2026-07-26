# SPDX-License-Identifier: MIT
{
  name = "oneplus-karen";
  family = "mt6893";

  identity = {
    marketingName = "OnePlus Nord 2T 5G";
    model = "CPH2399";
    productDevice = "OP557AL1";
    bootloaderBoardName = "k6893v1_64";
  };

  hardware = {
    architecture = "aarch64";
    screen = {
      width = 1080;
      height = 2400;
    };
  };

  stock = {
    version = "CPH2399_14.0.0.3001(EX01)";
    boot = {
      size = 67108864;
      sha256 = "7ad447405db4e74276395123c8029c67c63adc3fc6d82c4c180ae6c2e31882c0";
    };
    kernel = {
      size = 18927658;
      sha256 = "917716ae774cc32f71d1b7f7962e472ece9e5f82c1676e4362ac90b7219dac10";
    };
    dtb = {
      size = 210513;
      sha256 = "3f556b701b84247e529d4c05a46c7e45c9e29cffd4aca2c18822290de8d603c6";
    };
    dtbo = {
      size = 716800;
      sha256 = "3d644ab5fa1fb5a66c03b585152ae9d3294b768cbe2d36b6fd373048d217354c";
    };
  };

  bootImage = {
    headerVersion = 2;
    partitionSize = 67108864;
    pageSize = 2048;
    base = "0x40078000";
    kernelOffset = "0x00008000";
    ramdiskOffset = "0x11088000";
    tagsOffset = "0x07c08000";
    dtbOffset = "0x07c08000";
    includeDtb = true;
    usesRecoveryAsBoot = true;
    ab = true;
  };

  bootstrap = {
    kernelPolicy = "byte-identical-stock-until-control-kernel-gate";
    dtbPolicy = "byte-identical-stock-or-structurally-rebuilt";
    dtboPolicy = "preserve-stock";
    testMethod = "kexec-from-rooted-lineage";
    installationEnabled = false;
  };
}
