<!-- SPDX-License-Identifier: MIT -->

# Privacy profile

The profile changes package state for Android user 0. It does not modify
read-only partitions and is reversible without root. It was validated before
the 2026-07-24 bootloader unlock, whose mandatory userdata wipe reset the
profile. The current post-unlock audit reports no Aurora installation and
`0/21` hardening plus `0/24` Google-facing targets disabled. Reapply a profile
only when wanted; it is independent from stock-herstel and custom-ROM-porting.

## Profiles

`apply` installs the pinned F-Droid build of Aurora Store and disables Play
Store:

```bash
nix run .#privacy -- apply
```

`harden` also disables 21 Google personalization and OPlus
logging/diagnostics/telemetry packages:

```bash
nix run .#privacy -- harden
```

The list is a conservative subset of packages marked `Recommended` in
UAD-ng commit
`9336f25e7d5476e0824720ee44dce23bc7640c3f`. The exact list is versioned in
[`scripts/nord2t-privacy`](../scripts/nord2t-privacy).

`degoogle` adds 24 packages, including Play services, Google Services
Framework, Play Store, Google account/setup helpers, advertising and
personalization modules, and bundled network-facing Google consumer apps:

```bash
nix run .#privacy -- degoogle
```

OxygenOS refused the shell request for `com.google.android.gms.supervision`.
The helper logs refusals and continues instead of pretending the package was
changed. With the rest of Play services disabled, that package is not expected
to provide Google functionality by itself.

## Components deliberately retained

The profile keeps the stock dialer, messages, contacts, keyboard, TTS and
WebView until tested replacements are installed and selected. It also keeps:

- SystemUI and the permission controller;
- telephony, carrier, emergency and cell-broadcast services;
- Wi-Fi, Bluetooth, NFC and network modules;
- the OPlus camera;
- OPlus OTA, ROM update and security update services;
- critical Android Mainline metadata and configuration components.

The automated test rejects accidental addition of known critical packages to a
disable list.

## Compatibility trade-offs

Aurora is an alternative client for Google's Play distribution infrastructure,
not a Google-free software repository. Anonymous sessions avoid connecting a
personal Google account, but the service can still observe request and device
characteristics. Prefer F-Droid for open-source apps and use Aurora when an app
is unavailable elsewhere.

With Play services and GSF disabled, expect some or all of the following to
stop:

- Firebase Cloud Messaging push;
- Google account login;
- Google Wallet;
- Android Auto;
- carrier RCS implemented through Google Messages;
- Play Integrity;
- apps that directly depend on Google APIs.

Google Play System Updates can also stop. Android Mainline permits the OEM to
ship module updates in a normal OTA, but whether OnePlus does so consistently
is an OEM maintenance question.

microG is not a drop-in replacement on locked stock OxygenOS. Full
compatibility requires ROM-provided restricted signature spoofing. Patching
stock for that feature requires an unlocked bootloader and gives up the
verified stock baseline.

## Restore

Restore Google core and Google packages touched by both profiles, while leaving
OPlus telemetry disabled:

```bash
nix run .#privacy -- restore-google
```

Restore every conservative hardening package to its stock default:

```bash
nix run .#privacy -- restore-hardening
```

Restore only Play Store:

```bash
nix run .#privacy -- restore-play-store
```

A factory reset also restores stock package states. It is not needed merely to
apply or reverse these profiles.
