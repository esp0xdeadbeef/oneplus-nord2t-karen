# SPDX-License-Identifier: MIT
{
  bash,
  coreutils,
  gnugrep,
  gzip,
  jq,
  runCommand,
  writeShellApplication,
}: {
  expectedKernelSha256,
  kernelImage,
  kernelSource,
  name ? "karen-kernel-config-audit",
}: let
  auditTool = writeShellApplication {
    name = "karen-kernel-config-audit";
    runtimeInputs = [
      coreutils
      gnugrep
      jq
    ];
    text = builtins.readFile ../tools/kernel-config-audit;
  };
in
  runCommand name {
    nativeBuildInputs = [
      bash
      coreutils
      gnugrep
      gzip
    ];
  } ''
    actual_kernel_sha256="$(
      sha256sum ${kernelImage} |
        cut -d' ' -f1
    )"
    test "$actual_kernel_sha256" = ${expectedKernelSha256}

    gzip -dc ${kernelImage} >"$TMPDIR/Image"
    bash ${kernelSource}/scripts/extract-ikconfig \
      "$TMPDIR/Image" \
      >"$TMPDIR/config"
    test -s "$TMPDIR/config"

    ${auditTool}/bin/karen-kernel-config-audit \
      "$TMPDIR/config" \
      "$out"
    install -m 0644 "$TMPDIR/config" "$out/config"
  ''
