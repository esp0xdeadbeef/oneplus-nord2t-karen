<!-- SPDX-License-Identifier: MIT -->

# New-device recovery readiness

This procedure is for a new or completely functional `CPH2399` before its
first bootloader unlock, custom recovery, LineageOS installation or kernel
experiment. It deliberately treats a user-data backup and a recoverable phone
as different requirements.

A backup of photos, application data and accounts answers:

> Can the owner replace or wipe the phone without losing personal files?

Porting readiness instead answers:

> Can this exact physical phone be returned to a bootable, correctly
> calibrated state after its normal Android, recovery and fastboot paths have
> stopped working?

The latter requires all three of the following:

1. **Restore bytes:** verified factory images, exact live slot images,
   partition maps and private device state where appropriate.
2. **A surviving execution path:** a tested recovery on the other boot slot
   with proven fallback.
3. **A low-level write path:** a compatible authenticated MediaTek Download
   Agent or independently proven Boot ROM route.

Possessing only the first item is not enough. A backup cannot repair a phone
when no remaining interface is authorized to write it.

## Storage and privacy boundary

Choose a mounted, encrypted owner-controlled filesystem before collecting
anything private. Merely naming a normal directory `encrypted` does not
encrypt it. The examples below use a placeholder:

```text
/private/encrypted/karen/CPH2399-OWNER-LABEL/
```

Replace it with an actual LUKS, fscrypt or equivalent encrypted location.
Set its directory mode to `0700`. Keep two offline copies when practical.

The following must never enter Git, the Nix store, a public issue, an
untrusted repair ticket or the optional remote build host:

- ADB private keys and SOPS age identities;
- private APK, OTA, AVB or kernel-module signing keys;
- raw GPT or UFS captures containing a device-specific layout;
- `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`, `protect*`;
- modem, radio, IMEI, MAC-address or hardware-calibration state;
- raw logs containing the MediaTek ME ID, SoC ID or serial number;
- userdata, account data or application secrets.

Public firmware, public certificates, source code and scrubbed structural
facts may be built remotely. Private phone state must stay on a trusted owner
host.

## Phase 0: record untouched stock

Perform this phase before unlocking. Unlocking wipes userdata and changes the
security state that is being documented.

Create a rootless, identifier-filtered inventory:

```bash
nix run .#snapshot -- \
  /private/encrypted/karen/CPH2399-OWNER-LABEL/rootless-stock
```

This records the build, slot, Android security properties, partition names,
kernel, VINTF manifests, system OTA certificate archive and hashes. It is
diagnostic evidence, not a partition backup.

Place the pinned official packages in one local firmware directory. Verify
the archive bytes, payload metadata, whole-file signatures and signer
certificate, then compare that certificate with the one trusted by the
connected stock system:

```bash
nix run .#verify-firmware -- /private/firmware/nord2t
nix run .#verify-firmware -- \
  --device-cert /private/firmware/nord2t
```

The device certificate comparison must run while the untouched matching stock
system is available. The OTA certificate is public verification material. Its
presence does not provide OnePlus's private OTA-signing key.

Extract the complete public factory material and the narrower rollback set
directly to encrypted storage:

```bash
nix run .#extract-stock -- \
  --profile stock \
  --output \
  /private/encrypted/karen/CPH2399-OWNER-LABEL/stock-3001 \
  /private/firmware/nord2t/CPH2399_14.0.0.3001_OTA.zip

nix run .#extract-stock -- \
  --profile restore \
  --output \
  /private/encrypted/karen/CPH2399-OWNER-LABEL/restore-3001 \
  /private/firmware/nord2t/CPH2399_14.0.0.3001_OTA.zip
```

`stock` contains all 34 images present in the official payload. `restore`
contains the ten images used by the bounded Lineage-to-stock rollback:

```text
boot dtbo system system_ext product vendor odm
vbmeta vbmeta_system vbmeta_vendor
```

Keeping both sets is intentionally redundant: `stock` is the complete public
inventory, while `restore` is the already scoped transaction set consumed by
the restore workflow. Preserve their `SHA256SUMS`, `SOURCE.json`, the original
OTA and the repository commit and `flake.lock` that verified them.

These commands do **not** back up the physical phone. The OTA has no GPT,
UFS boot-region capture, Download Agent, service authorization,
`vendor_boot`, device-unique partitions or userdata.

## Phase 1: preserve host authorization and owner signing

### ADB host identity

Android authorizes an ADB host's public key. The corresponding private key is
normally `~/.android/adbkey` on the host, not a recoverable secret supplied by
the phone. If the display or touch later fails, generating a different host
key does not make that new key authorized.

Import or generate the key into the host-specific SOPS file:

```bash
nix run .#adb-key-generator
```

The command verifies that the local key and encrypted copy agree and derives
`adbkey.pub` from the private key. A private key is useful only while its
matching public key is authorized by Android or embedded in a private
key-bound recovery build.

Back up both of these independently:

```text
~/.android/adbkey
~/.config/sops/age/keys.txt
```

The committed `.age` document is not self-sufficient: losing every matching
age private identity makes the encrypted ADB key undecryptable. Keep the age
identity offline and never commit it.

The phone-side `/data/misc/adb/adb_keys` contains authorized public keys and is
lost with userdata. Do not depend on restoring that mutable file. Preserve the
host private key and use its public half in an audited private recovery when
headless recovery is a requirement.

### Owner application and kernel-module identities

For the opinionated owner build, create the stable APK and module identities
before depending on packages signed by them:

```bash
nix run .#vector-signing-key-generator
nix run .#kernel-module-signing-key-generator
```

Their shared SOPS documents contain only public certificates. Their private
documents contain the actual JKS or PEM material and remain decryptable only
on trusted owner hosts. Back up the matching SOPS age identities separately.

If custom Lineage OTA or AVB release keys are introduced later, treat their
private halves the same way. The current stock OTA and AVB public keys do not
allow the owner to sign an OPlus-trusted image; the OEM private keys are not
stored on the phone.

### What cannot be backed up from the phone

MediaTek Download Agent Authentication is a separate trust boundary. The
device contains an OEM trust anchor, but it does not contain the OPlus private
key, service account or reusable authorization needed to sign or authorize an
arbitrary Download Agent.

Backing up OTA certificates, AVB metadata, module certificates, ADB keys or
the preloader therefore does not create a DAA-capable service tool. A
compatible signed DA or supported exploit must be obtained and tested
independently and legitimately.

### Certificate and authorization inventory

The word “key” covers several unrelated trust systems in this project. Record
them separately:

| Material | Public or secret | Required action |
| --- | --- | --- |
| OPlus OTA signer certificate | Public | Capture through the rootless snapshot and verify with `verify-firmware --device-cert` |
| Stock AVB keys and descriptors | Public | Preserve the exact `vbmeta*` images from the OTA and live slots |
| Stock kernel-module certificate | Public | Preserve through the pinned stock boot/kernel extraction; it cannot sign new modules |
| ADB host private key | Secret, host-side | Run `adb-key-generator`, retain the SOPS copy and keep an offline owner backup |
| Authorized ADB public key | Public, phone-side authorization state | Preserve the matching host private key; optionally embed only the public half in an audited private recovery |
| SOPS age private identity | Secret, host-side root of access | Back up offline separately from the encrypted repository documents |
| Vector/AdAway owner JKS | Secret | Generate and retain only through the private SOPS document |
| Owner kernel-module PEM key | Secret | Generate and retain only through the private SOPS document |
| Future Lineage OTA/AVB release keys | Secret, not currently an owner release set | Generate and escrow before publishing builds or depending on signed updates |
| OPlus OTA/AVB private keys | OEM secret, unavailable | Cannot be extracted or backed up by the owner |
| OPlus DA signing/service authorization | OEM secret or service capability, unavailable | Must be obtained through an authorized service path or replaced by a proven supported exploit |

Copying a public certificate preserves the ability to verify a signature. It
does not preserve the ability to create a new signature. For owner-generated
identities, test decryption and public/private matching on the secondary
trusted owner host without printing the private key.

## Phase 2: collect exact live slot images

The official OTA contains unslotted payload images. The live A and B
partitions may contain different generations and padding. On the tested phone,
slot B retained an older boot generation and was not a `.3001` rollback
source.

The current stock-root helper is a persistent write: it replaces the active
stock boot image with a Magisk-patched copy. Run it only after Phase 0 has
verified the exact stock `boot.img` rollback:

```bash
nix run .#stock-root -- --persist --yes
```

First save the exact partition-name inventory to the private directory. Then
read only this reviewed non-unique allowlist:

```bash
KAREN_PRIVATE_ROOT=/private/encrypted/karen/CPH2399-OWNER-LABEL
KAREN_SLOT_ROOT="$KAREN_PRIVATE_ROOT/live-slots-after-stock-root"

install -d -m 0700 "$KAREN_SLOT_ROOT"
adb shell 'su -c "ls -1 /dev/block/by-name"' \
  >"$KAREN_SLOT_ROOT/partition-names.txt"

for KAREN_PARTITION in \
  boot_a boot_b vendor_boot_a vendor_boot_b \
  dtbo_a dtbo_b \
  vbmeta_a vbmeta_b \
  vbmeta_system_a vbmeta_system_b \
  vbmeta_vendor_a vbmeta_vendor_b
do
  adb shell \
    "su -c 'test -b /dev/block/by-name/$KAREN_PARTITION'" ||
    exit 1
  adb exec-out \
    "su -c 'dd if=/dev/block/by-name/$KAREN_PARTITION bs=4194304 2>/dev/null'" \
    >"$KAREN_SLOT_ROOT/$KAREN_PARTITION.img"
done

(
  cd "$KAREN_SLOT_ROOT"
  sha256sum ./*.img partition-names.txt >SHA256SUMS
  chmod 0600 ./*.img partition-names.txt SHA256SUMS
)
```

Because active `boot_a` has already been patched at this point, label this
capture accordingly. The pristine `.3001 boot.img` comes from the
cryptographically verified OTA. A genuinely pristine live `boot_a` readback
requires an independently working read-only DA path or a separately audited
root recovery that leaves A untouched.

Read stable boot-chain partitions twice and require the two captures to be
byte-identical before relying on them. Record each size and SHA-256. The
existing tested capture found both live `vendor_boot` partitions to be
64 MiB of zero bytes, but a new phone must verify its own state rather than
assume that result.

Return to exact stock after the capture:

```bash
nix run .#stock-unroot -- --persist --yes
```

Verify Android boot, the effective active slot, SELinux enforcing state and
the exact active boot hash again.

## Phase 3: collect device-unique state

Device-unique partitions are not interchangeable with another Nord 2T and
cannot be reconstructed from the OTA. They may contain modem identity,
network configuration, production data and hardware calibration.

At minimum, inspect the private partition-name inventory for:

```text
nvram nvdata nvcfg persist proinfo protect1 protect2
```

The exact names present on the phone are authoritative. Create an explicit
reviewed allowlist from that inventory; do not broaden a loop to every
`/dev/block/by-name` entry. Store each result with mode `0600`, its byte size,
two read hashes where the contents are stable, the build ID and the collection
method.

After confirming that every name below exists in the captured inventory, a
rooted Android fallback capture can use:

```bash
KAREN_PRIVATE_ROOT=/private/encrypted/karen/CPH2399-OWNER-LABEL
KAREN_UNIQUE_ROOT="$KAREN_PRIVATE_ROOT/device-unique-after-stock-root"
KAREN_UNIQUE_PARTITIONS=(
  nvram
  nvdata
  nvcfg
  persist
  proinfo
  protect1
  protect2
)

install -d -m 0700 "$KAREN_UNIQUE_ROOT"

for KAREN_PARTITION in "${KAREN_UNIQUE_PARTITIONS[@]}"; do
  adb shell \
    "su -c 'test -b /dev/block/by-name/$KAREN_PARTITION'" ||
    exit 1
  adb exec-out \
    "su -c 'dd if=/dev/block/by-name/$KAREN_PARTITION bs=4194304 2>/dev/null'" \
    >"$KAREN_UNIQUE_ROOT/$KAREN_PARTITION.img"
done

(
  cd "$KAREN_UNIQUE_ROOT"
  stat -c '%n %s' ./*.img >SIZES
  sha256sum ./*.img >SHA256SUMS
  chmod 0600 ./*.img SIZES SHA256SUMS
)
```

If the inventory uses different names, stop and review them rather than
silently skipping a partition or substituting a guessed name.

The preferred capture is a read-only authenticated DA session while storage
is quiescent. A rooted Android `dd` is a second-best fallback: modem and vendor
state can change while Android runs, so two differing reads are not proof of
corruption and neither is an atomic whole-device snapshot.

These images are last-resort repair inputs, not an automatic restore set.
Never blindly restore old `metadata`, `misc`, `para`, `seccfg`, `frp`,
userdata or every partition in a raw dump. They can describe encryption,
factory-reset protection, slot state or bootloader state that no longer
matches the rest of storage.

Back up personal content separately through Android-aware tools. Raw
file-based-encrypted userdata is generally not a useful replacement for that
backup because its keys and matching metadata are required.

## Phase 4: prove low-level read and write access

The current read-only gate is:

```bash
nix run .#probe-preloader
nix run .#read-gpt
```

The first command records only non-unique MediaTek security flags. The second
tries to obtain two byte-identical GPT reads without sending a storage write,
erase or format command.

On the tested Nord 2T, preloader probing works but generic public Download
Agents are rejected by DAA. `read-gpt` has not produced GPT bytes. Therefore
the repository currently has no proven self-service hardbrick restore.

Before treating a future route as recovery, require all of the following:

1. a reviewed, lawful and compatible authenticated DA or proven Boot ROM
   route;
2. two byte-identical primary and backup GPT reads;
3. captures of both UFS boot regions and the UFS LUN geometry;
4. a mapping from every intended OTA image to its exact physical target;
5. a read of inactive `boot_b`;
6. one bounded write to `boot_b`, followed by an exact readback;
7. restoration of the original `boot_b`, followed by another exact readback;
8. a normal verified Android boot after the exercise.

A raw full-UFS image without the authenticated write route still cannot
recover a preloader-only phone. Conversely, a working service route without
the exact target map can make a recoverable problem worse. Never test this by
writing GPT, preloader, radio or device-unique partitions first.

## Phase 5: establish an independent rescue boot

Keep the working daily system on `boot_a`. Save `boot_b`, then install an
already audited Lineage Recovery only on B and verify:

- visible recovery display;
- authenticated root ADB;
- `ro.boot.slot_suffix=_b`;
- return to bootloader-fastboot with `adb shell reboot bootloader`;
- selection and successful boot of A;
- exact restoration and readback of the saved B image.

The repository has proven that manual inactive-slot roundtrip. It has not yet
proven an automatic retry/fallback policy for a failed kernel. Before relying
on A/B protection, deliberately verify that an unproven B candidate exhausts
its retry counter and the bootloader returns to the known-good A slot without
ADB, touch or host intervention.

Until that automatic fallback test exists, do not equate “candidate written
to the inactive slot” with guaranteed recovery.

For a new kernel, the first persistent test must be a self-contained recovery
canary on B. It may not replace the working Android kernel on A. Only after
that canary, a zero-mismatch kernel-module ABI audit and the fallback test pass
may an active-slot Android kernel be considered.

## Phase 6: rehearse each restore level

Run the least invasive applicable drill before moving to the next risk level:

1. **Android available:** stock root/unroot restores the exact active boot.
2. **Recovery available:** recovery ADB reaches bootloader-fastboot and
   restores the audited boot/AVB pair.
3. **Bootloader-fastboot available:** exact `boot_a` and matching AVB metadata
   are restored without touching unrelated partitions.
4. **Only preloader available:** the authenticated DA reads current GPT and
   writes only the explicitly selected damaged partition.

Record the exact cable and host port used. Karen's bootloader-fastboot was
observable over a direct laptop cable but not through the tested dock.
`fastboot boot` is not a rescue mechanism on this loader: accepted transfers
returned through `lk_crash` without executing the image.

## Mandatory stop gates

| Proposed operation | Required evidence |
| --- | --- |
| Unlock and ordinary Lineage installation | User-data backup, verified OTA, `stock` and `restore` sets |
| Root or boot-pair modification | Exact stock boot/AVB rollback and direct bootloader-fastboot |
| Inactive-slot recovery experiment | Saved original B image and proven manual A return |
| Experimental kernel recovery canary | Known-good A, working B recovery, kernel/image audit |
| Experimental active-slot kernel | Zero module-ABI mismatches, B recovery canary, automatic fallback, and preferably proven authenticated DA |
| GPT, preloader or whole-device write | Proven DA, GPT plus UFS boot-region backups, target map and anti-rollback review |

When the low-level DA gate is unavailable, the safe scope ends at operations
whose failure still leaves a separately proven recovery or bootloader path.
“All user data is backed up” does not waive this gate: it permits a wipe or
replacement, not an avoidable motherboard-level recovery.

## Counterfactual for the 2026-07-26 incident

The incident wrote an experimental kernel only to active `boot_a`. The phone
still reaches LK's Orange State screen and enumerates as OPlus preloader, but
Android, recovery and fastboot no longer start. Public DAs are rejected before
UFS access.

The preparation layers would have changed the outcome as follows:

| Preparation completed beforehand | Effect after the bad `boot_a` write |
| --- | --- |
| Verified OTA plus `stock`/`restore` only | Supplies the correct stock `boot.img`, but no current interface can write it |
| Exact live `boot_a` backup only | Same limitation: correct bytes without an authorized writer |
| Device-unique backup only | Protects identity and calibration during a later full flash, but does not fix this bootloop |
| Full UFS backup without a signed DA | Still cannot write the backup |
| Proven B recovery plus automatic fallback | Would likely have returned to recovery or the known-good slot without low-level flashing |
| Proven authenticated DA plus exact stock boot | Could now restore only `boot_a`; given the recorded write set, that would probably be sufficient |
| New kernel tested only as a recovery canary on B | Would have left working `boot_a` untouched and avoided the present state |

The phone is therefore still a deep softbrick rather than an electrically dead
device, but self-service recovery remains blocked by authorization rather than
by absence of the stock image. An OPlus-authorized service tool should be able
to attempt a targeted `boot_a` restore before a full flash or motherboard
replacement.

## Completion record

Before declaring a new phone porting-ready, retain a private manifest recording:

- model, region, stock build and security patch;
- repository commit and `flake.lock` hash;
- OTA filename, size, signature result and SHA-256;
- `stock`, `restore`, rootless snapshot and live-slot manifest hashes;
- encrypted location and offline-copy status;
- ADB public-key fingerprint and confirmation that its private key and SOPS
  age identity are independently recoverable;
- owner signing-certificate fingerprints where applicable;
- active slot, exact saved B image and recovery/fallback results;
- GPT and UFS boot-region hashes;
- DA/security flags and whether authenticated read/write was actually proven;
- the highest-risk operation currently authorized by the passed gates.

Repeat the affected portions after a stock firmware update. A new OTA may
change boot firmware, AVB metadata, partition contents, rollback indexes and
the correct vendor/kernel pairing.
