# SPDX-License-Identifier: MIT
args: let
  lineage = import ./lineage.nix args;
  nixos = import ./nixos.nix args;
in {
  inherit lineage nixos;

  public = lineage.public // nixos.public;
}
