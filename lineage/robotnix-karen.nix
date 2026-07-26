# SPDX-License-Identifier: MIT
{
  adbPublicKey ? null,
  buildSourceKernel ? false,
  deviceTree,
  fullSystem ? false,
  insecureRecoveryAdb ? false,
  kernelModules ? null,
  kernelSource ? null,
  lineageLockfile,
  vendorLineagePatches,
  webviewSource ? null,
}: {lib, ...}:
lib.mkMerge [
  {
    flavor = "lineageos";
    flavorVersion = "21.0";
    device = "karen";
    deviceDisplayName = "OnePlus Nord 2T 5G";
    variant = "userdebug";
    release = "ap2a";
    stateVersion = "3";

    # Build scratch space is already isolated by Nix. Keeping ccache disabled
    # makes the result independent from mutable host state.
    ccache.enable = false;

    # Robotnix's generated Lineage lock also contains TheMuppets vendor trees
    # for every supported phone. Karen has no matching entry and derives its
    # stock inputs independently, so do not realize those unrelated blobs.
    source.manifest.lockfile = lib.mkForce lineageLockfile;
    source.dirs."device/oneplus/karen".src = lib.mkForce deviceTree;

    # The current pinned Lineage 21 vendor revision has the Android 14
    # bootanimation layout. Robotnix 21.0 selects its older patch by default,
    # while its newer `-21` patch applies cleanly to this exact source.
    source.dirs."vendor/lineage".patches = lib.mkForce vendorLineagePatches;
  }

  (lib.mkIf (webviewSource != null) {
    # Robotnix's generated Lineage lock is deliberately retained for the
    # complete source graph. Override only the arm64 prebuilt WebView with an
    # independently content-pinned, hardware-tested upstream revision.
    source.dirs."external/chromium-webview/prebuilt/arm64".src =
      lib.mkForce webviewSource;
  })

  (lib.mkIf insecureRecoveryAdb {
    # Only the temporary recovery-as-boot probe disables ADB authentication so
    # a freshly wiped device can provide bring-up logs. Never set this on an
    # installable system build.
    envVars.WITH_ADB_INSECURE = "true";
  })

  (lib.mkIf (adbPublicKey != null) {
    # Owner-only authenticated recovery access. The caller may provide one
    # public Android host key; private key material never enters this graph.
    envVars.KAREN_DEBUG_ADB_KEYS = toString adbPublicKey;
  })

  (lib.mkIf fullSystem {
    envVars.KAREN_FULL_SYSTEM = "true";
  })

  (lib.mkIf buildSourceKernel {
    assertions = [
      {
        assertion = kernelSource != null;
        message = "Karen source-kernel builds require the pinned OnePlus kernel source";
      }
      {
        assertion = kernelModules != null;
        message = "Karen source-kernel builds require the pinned OnePlus/MediaTek module source";
      }
    ];
    envVars.KAREN_BUILD_SOURCE_KERNEL = "true";
    source.dirs."kernel/oneplus/mt6893".src = lib.mkForce kernelSource;
    # The published kernel contains relative links into both of these trees.
    # They come from the matching, independently pinned OnePlus module source.
    source.dirs."kernel/oneplus/vendor/mediatek/kernel_modules".src =
      lib.mkForce (kernelModules + /vendor/mediatek/kernel_modules);
    source.dirs."kernel/oneplus/vendor/oplus".src =
      lib.mkForce (kernelModules + /vendor/oplus);
  })
]
