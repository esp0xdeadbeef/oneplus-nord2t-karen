# SPDX-License-Identifier: MIT
{
  android-tools,
  coreutils,
  diffutils,
  lib,
  runCommand,
  dtc,
  findutils,
  gnugrep,
  jq,
  patch,
  writeShellApplication,
}: {
  inputDtb,
  patches ? [],
  expectedInputSha256 ? null,
  name ? "karen-dtb-workspace",
}: let
  dtbWorkspace = writeShellApplication {
    name = "karen-dtb-workspace";
    runtimeInputs = [
      android-tools
      coreutils
      diffutils
      dtc
      findutils
      gnugrep
      jq
      patch
    ];
    text = builtins.readFile ../tools/dtb-workspace;
  };
  patchSet = runCommand "${name}-patches" {} ''
    mkdir -p "$out"
    ${lib.concatImapStringsSep "\n" (
        index: patchFile:
          "cp ${lib.escapeShellArg (toString patchFile)} "
          + "\"$out/${lib.fixedWidthNumber 4 index}-${builtins.baseNameOf patchFile}\""
      )
      patches}
  '';
in
  runCommand name {
    nativeBuildInputs = [
      dtc
      jq
      patch
    ];
  } ''
    ${lib.optionalString (expectedInputSha256 != null) ''
      actual_input_sha256="$(sha256sum ${lib.escapeShellArg (toString inputDtb)} | cut -d' ' -f1)"
      test "$actual_input_sha256" = ${lib.escapeShellArg expectedInputSha256}
    ''}

    ${dtbWorkspace}/bin/karen-dtb-workspace \
      ${lib.escapeShellArg (toString inputDtb)} \
      ${patchSet} \
      "$out"
  ''
