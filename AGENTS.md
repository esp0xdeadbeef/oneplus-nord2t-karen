
Read https://docs.ubports.com/en/latest/porting/introduction/Intro.html for an introduction to porting.

# AI Coding Assistants

This document provides guidance for AI tools and developers using AI assistance when contributing to
the LineageOS Project.

The use of “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”,
“RECOMMENDED”, “MAY”, and “OPTIONAL” is per the IETF standard defined in RFC2119.

AI tools helping with LineageOS development SHOULD follow the
[device support requirements](https://github.com/LineageOS/charter/blob/main/device-support-requirements.md).

## Licensing and Legal Requirements

All contributions MUST comply with the
[Licensing](https://github.com/LineageOS/charter/blob/main/device-support-requirements.md#licensing)
section of the Device Support Requirements:

- Use appropriate SPDX license identifiers
- See each repository's LICENSE and upstream licensing rules for details

## Responsibility

The human submitter is responsible for:

- Reviewing all AI-generated code
- Ensuring compliance with licensing requirements
- Accepting accountability for any licensing issues arising from the contribution
- Addressing any feedback and requests for changes raised by reviewers, until the contribution is
  approved and merged

## Attribution

When AI tools contribute to LineageOS development, proper attribution helps track the evolving role
of AI in the development process. Contributions MUST include an `Assisted-by` tag in the following
format:

```text
Assisted-by: AGENT_NAME:MODEL_VERSION
```

Where:

- `AGENT_NAME` is the name of the AI tool or framework
- `MODEL_VERSION` is the specific model version used

Example:

```text
Assisted-by: Claude-Code:claude-opus-4.7
```

## Nix command entrypoints

Repository workflows and exported build artifacts SHOULD use the flake's
`nix run .#APP -- ...` entrypoints. Assistants MUST NOT copy, hardcode or
discover executable `/nix/store/...` paths for a command that Nix can resolve.

For a short ad-hoc check, use `nix run nixpkgs#PACKAGE -- ...` when the wanted
executable is the package's main program. If a package exposes several
programs and the wanted one is not its main program, use:

```text
nix shell nixpkgs#PACKAGE --command PROGRAM ...
```

For example, `fdtoverlay` is a secondary executable from `dtc`, so invoke it
as `nix shell nixpkgs#dtc --command fdtoverlay ...` instead of searching the
Nix store for its path.

## Live device state

The optional `root-full` profile can deliberately mask Android boot
properties, including the display build ID, verified-boot state and flash-lock
state. Assistants MUST NOT infer the installed OS or bootloader state from
those properties alone. Cross-check Lineage identity separately, use
bootloader-fastboot for the physical unlock state, and inspect the effective
running kernel configuration before making a flash or kexec decision.
