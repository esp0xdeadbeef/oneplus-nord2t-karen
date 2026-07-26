# SPDX-License-Identifier: MIT
{
  pkgs,
  self,
  system,
}: let
  repositoryRoot = ../.;
in {
  inherit
    (self.packages.${system})
    adb-key-generator
    audit-boot
    audit-kernel-module-abi
    audit-lineage-images
    audit-lineage-runtime
    extract-stock
    install-aurora
    kernel-module-owner-build
    kernel-module-owner-sign
    kernel-module-sign-file
    kernel-module-signing-key-generator
    lineage-keybound-adb
    lineage-root
    lineage-root-full
    lineage-unroot
    lineage-userspace
    owner-sign-apk
    preflight-lineage-userspace
    probe-preloader
    read-gpt
    repack-control-vendor
    snapshot
    vector-owner-build-intermediate
    vector-owner-sign
    vector-signing-key-generator
    verify-firmware
    ;

  adb-key-generator-test =
    pkgs.runCommand "nord2t-adb-key-generator-test" {
      nativeBuildInputs = with pkgs; [
        age
        android-tools
        bash
        coreutils
        gnugrep
        gnused
        sops
      ];
      src = repositoryRoot;
    } ''
      bash "$src"/tests/adb-key-generator.sh
      touch "$out"
    '';

  shellcheck =
    pkgs.runCommand "nord2t-shellcheck" {
      nativeBuildInputs = [pkgs.shellcheck];
      src = repositoryRoot;
    } ''
      shellcheck "$src"/scripts/*
      shellcheck "$src"/tests/*.sh
      touch "$out"
    '';

  firmware-metadata =
    pkgs.runCommand "nord2t-firmware-metadata" {
      nativeBuildInputs = [
        pkgs.bash
        pkgs.jq
      ];
      src = repositoryRoot;
    } ''
      bash "$src"/tests/firmware-metadata.sh
      touch "$out"
    '';

  package-safety =
    pkgs.runCommand "nord2t-package-safety" {
      nativeBuildInputs = [
        pkgs.bash
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.jq
      ];
      src = repositoryRoot;
    } ''
      bash "$src"/tests/package-safety.sh
      touch "$out"
    '';

  preloader-safety =
    pkgs.runCommand "nord2t-preloader-safety" {
      nativeBuildInputs = [
        pkgs.bash
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
      ];
      src = repositoryRoot;
    } ''
      bash "$src"/tests/preloader-safety.sh
      touch "$out"
    '';

  stock-boot-safety =
    pkgs.runCommand "nord2t-stock-boot-safety" {
      nativeBuildInputs = [
        pkgs.bash
        pkgs.coreutils
        pkgs.gnugrep
      ];
      src = repositoryRoot;
    } ''
      bash "$src"/tests/stock-boot-safety.sh
      touch "$out"
    '';
}
