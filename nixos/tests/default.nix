# SPDX-License-Identifier: MIT
let
  repository = builtins.getFlake (toString ../..);
  system = builtins.currentSystem;
  pkgs = import repository.inputs.nixpkgs {inherit system;};
  mkDtbWorkspace = pkgs.callPackage ../lib/mk-dtb-workspace.nix {};
  fixtureDts = pkgs.writeText "karen-dtb-fixture.dts" ''
    /dts-v1/;

    / {
      compatible = "oneplus,karen";
      model = "Karen Nix fixture";

      chosen {
        bootargs = "fixture=base";
      };
    };
  '';
  fixtureDtb =
    pkgs.runCommand "karen-dtb-fixture.dtb" {
      nativeBuildInputs = [pkgs.dtc];
    } ''
      dtc -q -I dts -O dtb -o "$out" ${fixtureDts}
    '';
  fixturePatch = pkgs.writeText "0001-change-fixture-bootargs.patch" ''
    --- a/karen.dts
    +++ b/karen.dts
    @@ -1 +1 @@
    -		bootargs = "fixture=base";
    +		bootargs = "fixture=patched";
  '';
  fixtureWorkspace = mkDtbWorkspace {
    name = "karen-dtb-nix-fixture-workspace";
    inputDtb = fixtureDtb;
    patches = [fixturePatch];
  };
in {
  dtbWorkspace =
    pkgs.runCommand "karen-dtb-nix-workspace-test" {
      nativeBuildInputs = [
        pkgs.gnugrep
        pkgs.jq
      ];
    } ''
      jq -e '
        .schemaVersion == 1 and
        .inputFormat == "raw-fdt" and
        (.patches | length) == 1 and
        .inPlaceBinaryPatch == false
      ' ${fixtureWorkspace}/manifest.json >/dev/null
      grep -Fq \
        'bootargs = "fixture=patched";' \
        ${fixtureWorkspace}/compiled.dts
      touch "$out"
    '';
}
