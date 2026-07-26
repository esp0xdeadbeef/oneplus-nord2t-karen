<!-- SPDX-License-Identifier: MIT -->

# Optional remote Android build host

Nothing in this repository requires `s-tau`. All Nix and Android build
commands can run on the machine that holds the checkout when it has enough
memory and storage. References to `s-tau` elsewhere in the documentation are
either historical build provenance or paths from the repository owner's
current setup.

The owner uses `s-tau` only because full LineageOS builds exhausted the memory
available on `l-esp`. This is an SSH/rsync build-host workflow, not a
repository-level Nix remote-builder dependency. Other users may build locally,
choose another build host or configure Nix distributed builds outside this
repository.

## Owner host split

| Host | Responsibility |
| --- | --- |
| `l-esp` | Authoritative Git checkout, phone USB, audits, flash actions and trusted final signing |
| `l-portal` | Secondary trusted owner host; can decrypt both Vector signing documents and perform final signing |
| `s-tau` | Optional compilation, public Vector certificate, persistent Android checkout, compiler cache and staged non-unique images |

The phone is never flashed from `s-tau`. Device-unique data, the ADB private
key, runtime captures and calibration/radio/persistent partitions stay off the
remote build host. A private authenticated-ADB build needs only the public
`adbkey.pub`; vanilla builds need no ADB key at all. Owner-signed Vector
builds give `s-tau` only the SOPS-encrypted shared certificate metadata. Its
private JKS is decryptable by `l-esp` and `l-portal`, never by `s-tau`.

The paths below document the owner's current layout. They are examples, not
interfaces that scripts or other installations must reproduce:

```text
l-esp repository:
  /home/deadbeef/github/oneplus-nord2t-karen

s-tau repository mirror:
  /home/deadbeef/build/oneplus-nord2t-karen-codex

s-tau persistent Android checkout:
  /home/deadbeef/build/lineage-21-karen-incremental

s-tau ccache:
  /home/deadbeef/.cache/nord2t-ccache
```

## Local build remains the default

The reproducible flake targets need no remote-host setup:

```sh
nix run .#karen-bootimage
nix run .#karen-full-images
```

For faster mutable Android iteration, prepare a persistent checkout and use
the same FHS build environment locally:

```sh
nix run .#extract-stock -- --profile boot
nix run .#extract-stock -- --profile lineage
nix shell nixpkgs#jq nixpkgs#python3 --command \
  scripts/prepare-lineage --full /path/to/lineage-21

cd /path/to/lineage-21
nix run /path/to/oneplus-nord2t-karen#android-fhs -- -c '
  source build/envsetup.sh
  export KAREN_FULL_SYSTEM=true
  lunch lineage_karen-ap2a-userdebug
  m bootimage systemimage systemextimage productimage \
    vendorimage odmimage vbmetaimage vbmetasystemimage vbmetavendorimage
  m checkvintf
  /path/to/oneplus-nord2t-karen/scripts/audit-lineage-vintf "$PWD"
'
```

See the [interactive checkout notes](lineage-port.md#interactive-checkout) for
the recovery-only variant and the exact target-name warning.

## Optional `s-tau` workflow

The owner uses one shell variable for commands referenced by the resumable
follow-up:

```sh
export KAREN_BUILD_HOST=s-tau
```

Run the source sync from the repository root on `l-esp`. The target must be
the dedicated repository mirror shown here, never the persistent Android
checkout or a broader home/build directory:

```sh
repository_root="$(git rev-parse --show-toplevel)"
rsync -ani --delete \
  --exclude='.git/' \
  --filter=':- .gitignore' \
  "$repository_root/" \
  s-tau:/home/deadbeef/build/oneplus-nord2t-karen-codex/
```

Review that dry-run before repeating it without `-n`:

```sh
repository_root="$(git rev-parse --show-toplevel)"
rsync -a --delete \
  --exclude='.git/' \
  --filter=':- .gitignore' \
  "$repository_root/" \
  s-tau:/home/deadbeef/build/oneplus-nord2t-karen-codex/
```

The `.gitignore` filter keeps stock-derived prebuilts, Android outputs, runtime
captures and plaintext local configuration out of this transfer. `--delete`
removes stale source files from this one dedicated mirror; omit it when the
destination has not been positively identified.

Prepare the persistent Android checkout on `s-tau`, then run the same FHS
command as above with these path substitutions:

```text
/path/to/oneplus-nord2t-karen
  -> /home/deadbeef/build/oneplus-nord2t-karen-codex

/path/to/lineage-21
  -> /home/deadbeef/build/lineage-21-karen-incremental
```

The owner's current incremental state was built with that second directory
bind-mounted at `/build`. Continue to expose it at exactly `/build` when
reusing its `out` directory: Android's generated depfiles contain absolute
paths, and changing the visible path causes a large rebuild. The current
transient user service names and status commands are recorded in the
[resumable follow-up](follow-up.md#resume-commands). User lingering and
systemd user services are conveniences for surviving an SSH disconnect; they
are not repository or LineageOS requirements.

For a key-bound diagnostic recovery, transfer only the public ADB key to a
private non-repository path on `s-tau` and point `KAREN_DEBUG_ADB_KEYS` there.
Do not transfer `~/.android/adbkey` or the SOPS age identity. The normal image
audit deliberately rejects the resulting private image unless its explicit
bring-up exception is supplied.

Vector uses a separate split identity. `s-tau` decrypts
`secrets/vector-signing-shared.json.age` with its normal-user repository age
identity and runs `vector-owner-build-intermediate`; it cannot decrypt
`secrets/vector-signing-private.json.age`. Return the intermediate module to
`l-esp` or `l-portal` and run `vector-owner-sign` there. The private keystore
and passwords never enter a Nix derivation, the Nix store or the remote
builder.

## Return and verify artifacts

Stage the requested images outside Android's `out` tree on `s-tau`, create a
hash manifest, then copy that bounded candidate directory back to `l-esp`.
For example:

```sh
rsync -a --checksum \
  s-tau:/home/deadbeef/build/lineage-21-karen-images-CANDIDATE/ \
  /home/deadbeef/build/lineage-21-karen-images-CANDIDATE/

nix run .#audit-lineage-images -- \
  /home/deadbeef/build/lineage-21-karen-images-CANDIDATE
```

Verify the transferred hash manifest as well when the candidate contains one.
Only the copy on the phone host may proceed to live preflight and bounded
flash helpers. A successful remote compile is not flash authorization.

## Cache policy and reminder

The repository's `android-fhs` environment enables `ccache` and currently
sets its maximum size to 400 GB. That limit does not preallocate 400 GB, but a
long-lived checkout can eventually consume that much. Preserving Android's
`out` directory usually saves more rebuild time than compiler cache alone.
The FHS namespace only supplies the conventional host filesystem layout Soong
expects. Every package it exposes still comes from the nixpkgs revision pinned
by this repository's `flake.lock`; it is not an alternate or floating package
source.

> Owner reminder (review by 2027-07-25): reassess the 400 GB `s-tau` ccache
> limit and the lingering build-user setup. Reduce or remove them when this
> port is no longer under active development.

Other builders should select a cache limit appropriate to their storage and
need not reproduce the owner's `s-tau` retention policy.
