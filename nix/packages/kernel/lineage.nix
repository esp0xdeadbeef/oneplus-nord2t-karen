# SPDX-License-Identifier: MIT
{
  oneplus-kernel-modules,
  oneplus-kernel-source,
  pkgs,
  ...
}: let
  oneplusKernelSource = pkgs.runCommand "oneplus-karen-kernel-source" {} ''
    ln -s ${oneplus-kernel-source} "$out"
  '';

  oneplusKernelModules = pkgs.runCommand "oneplus-karen-kernel-modules" {} ''
    ln -s ${oneplus-kernel-modules}/vendor/mediatek/kernel_modules "$out"
  '';
in {
  inherit
    oneplusKernelModules
    oneplusKernelSource
    ;

  public = {
    oneplus-kernel-modules = oneplusKernelModules;
    oneplus-kernel-source = oneplusKernelSource;
  };
}
