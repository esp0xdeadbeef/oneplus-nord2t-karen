# SPDX-License-Identifier: MIT
{pkgs}: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      age
      alejandra
      android-tools
      coreutils
      curl
      erofs-utils
      git
      git-lfs
      git-repo
      jq
      libarchive
      mkbootimg-osm0sis
      mtkclient
      openssl
      p7zip
      payload-dumper-go
      shellcheck
      sops
    ];
  };
}
