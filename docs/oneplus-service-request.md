<!-- SPDX-License-Identifier: MIT -->

# OnePlus service request

## Incident summary

The affected device is a OnePlus Nord 2T 5G, model CPH2399.

Before the incident, the phone was operational with LineageOS 21 based on
Android 14, Magisk, an unlocked bootloader and slot A active.

On 26 July 2026, an experimental source-built Linux 4.19 control kernel with
`CONFIG_KEXEC=y` was packaged in a Magisk-patched `boot.img`. The image was
written through ordinary bootloader-fastboot to active `boot_a`. The fastboot
write completed, but the phone did not boot afterwards.

The experimental kernel had passed structural boot-image checks, but that did
not prove runtime compatibility. The repository still recorded unresolved
kernel-module ABI differences and explicitly treated the source-built result
as build evidence rather than a proven flash candidate.

The incident write targeted only `boot_a`. It did not intentionally write the
preloader, GPT, modem, calibration, persistent, radio or other device-unique
partitions.

After the reboot:

- the display repeatedly showed the unlocked-bootloader warning:

  ```text
  Orange State

  Your device has been unlocked and can't be trusted
  Your device will boot in 5 seconds.
  ```

- the device rebooted again after this warning, creating a boot loop;
- Android ADB did not enumerate;
- recovery, fastbootd and bootloader-fastboot could not be reached;
- the device still enumerated transiently over USB as `22d9:0006`, identified
  as `OPLUS Preloader`.

The visible warning proves that the display and early OPlus bootloader stage
still execute. The failure occurs later, while attempting to continue into
the flashed boot image or its kernel.

A MediaTek preloader handshake identified the MT6893 platform family and
reported:

- Secure Boot Check enabled;
- Download Agent Authentication enabled;
- Serial Link Authentication disabled;
- no root-certificate requirement;
- no separate memory-read or memory-write authentication flag;
- command `0xC8` not blocked.

Both the generic MediaTek V5 Download Agent and the larger public Download
Agent distributed with a third-party SP Flash Tool package were rejected with:

```text
DAA_SIG_VERIFY_FAILED (0x7024)
```

No Download Agent was successfully executed. No GPT data was obtained, and
the subsequent recovery attempts did not successfully erase, format or write
device storage.

The observed state is therefore consistent with a deep software brick rather
than a completely non-responsive mainboard. Recovery likely requires an
OPlus-authorized MediaTek Download Agent, service account and current
anti-rollback-compatible CPH2399 firmware.

Raw diagnostic logs can contain device-unique ME ID and SoC ID values. Do not
attach or publish those logs without sanitizing them first.

## Contact

OnePlus Netherlands currently lists these support channels:

- email: `support.nl@oneplus.com`;
- telephone: `+31 85 2083 289`;
- support and chat: <https://service.oneplus.com/nl/contact>;
- repair request: <https://service.oneplus.com/nl/repair>.

Do not include the device IMEI in an initial ordinary email. Supply it through
the official service form or another secure OnePlus support channel when
requested.

### Netherlands repair lead

ThePhoneLab's official page identifies its Potterstraat branch as a OnePlus
Independent Repair Provider. Its current contact details are:

- ThePhoneLab Potterstraat, Potterstraat 4, 3512 TA Utrecht;
- telephone: `030 737 08 72`;
- mobile and WhatsApp: `06 41 42 29 91`;
- Monday through Friday 09:00–19:00, Saturday 10:00–18:00 and Sunday
  12:00–17:00;
- <https://thephonelab.nl/locaties/utrecht/potterstraat-utrecht/>.

Ask to speak with a technician familiar with OnePlus software or mainboard
recovery. The desired outcome is a complete official CPH2399 stock-firmware
and stock-partition-layout restoration, with working boot, recovery and
fastboot. A data wipe is acceptable, but device-unique IMEI, modem, calibration
and persistent data must not be replaced with data from another phone.

Ask whether the branch's OnePlus service tooling includes an OPlus-authorized
MediaTek Download Agent or service authorization capable of handling
`DAA_SIG_VERIFY_FAILED` on `22d9:0006`. Restoring only the known-damaged
`boot_a` first is a useful minimally invasive diagnostic, not a restriction on
the requested final repair. Do not relock the bootloader until matching
official firmware has booted successfully.

## Suggested email

**Subject: Authorized software recovery referral – OnePlus Nord 2T 5G CPH2399 stuck in OPLUS Preloader**

Hello OnePlus Support,

I am looking for an authorized repair company in the Netherlands or elsewhere
in the EU that can perform a low-level software recovery on a OnePlus Nord 2T
5G, model CPH2399.

On 26 July 2026, the phone was operational with an unlocked bootloader and
Android 14. Using ordinary bootloader fastboot, an experimental self-built
`boot.img` containing a modified Linux 4.19 kernel and Magisk was written to
the active `boot_a` partition. The fastboot write completed, but the device no
longer booted afterwards.

Current condition:

- The display shows the following unlocked-bootloader warning:

  `Orange State — Your device has been unlocked and can't be trusted. Your
  device will boot in 5 seconds.`

- The device then reboots and repeats this sequence.
- No Android ADB, recovery, fastbootd or bootloader-fastboot.
- The device still enumerates temporarily over USB as `22d9:0006`, “OPLUS
  Preloader”.
- A MediaTek preloader handshake identifies the MT6893 platform family.
- Secure Boot Check and Download Agent Authentication are enabled.
- Serial Link Authentication is reported as disabled.
- Public or generic MediaTek Download Agents are rejected with
  `DAA_SIG_VERIFY_FAILED (0x7024)`.
- No successful GPT read, erase, format or storage write has occurred during
  the recovery attempts.

Only `boot_a` was intentionally modified during the incident. The preloader,
GPT, modem, calibration, persist and other device-specific partitions were not
intentionally written.

All important user data is backed up. I want the phone restored to the
complete official CPH2399 stock-firmware and stock-partition state, including
working boot, recovery and fastboot. A complete data wipe is acceptable.
Device-unique IMEI, modem, calibration and persistent data should be preserved.
I understand that the unlocked bootloader and custom software make this an
out-of-warranty repair, and I am willing to pay for diagnosis and recovery.

Could you please confirm:

1. Whether the official OnePlus send-in repair service can restore the
   complete official stock firmware and partition state using an
   OPlus-authorized MediaTek Download Agent or service account and current
   CPH2399 firmware.
2. Whether a software recovery can be attempted before replacing the
   motherboard.
3. If your regular service cannot perform this procedure, the name and contact
   details of an authorized repair company in the Netherlands or EU that can.
4. The expected diagnostic and repair charges.

I can provide the IMEI, proof of purchase and additional diagnostic
information through a secure support channel when requested.

Kind regards,

[Name]<br>
[Country or city]<br>
[Telephone number]
