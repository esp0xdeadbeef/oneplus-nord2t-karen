# SPDX-License-Identifier: MIT
args: let
  artifacts = import ./artifacts.nix args;
  deviceTools = import ./device-tools.nix (args // {inherit artifacts;});
  kernel =
    import ./kernel
    (args
      // {
        inherit deviceTools;
      });
  lineage =
    import ./lineage.nix
    (args
      // {
        inherit artifacts deviceTools kernel;
      });
in
  artifacts.public
  // kernel.public
  // deviceTools.public
  // lineage.public
