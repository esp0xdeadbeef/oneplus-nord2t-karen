<!-- SPDX-License-Identifier: MIT -->

# Karen kernel patches

Kernel patches belong in the dedicated Karen fork of
`OnePlusOSS/android_kernel_oneplus_mt6893`, initially based on commit
`a5cdca1a88dc328a44dee724193830254fc551da`.

This integration repository records only the pinned kernel revision and any
small integration patch list. Do not commit patched `Image`, `Image.gz`,
modules or byte-offset patch recipes here.

The initial configuration delta is tracked at
`families/mt6893/kernel/nixos-control.config`. It enables classic kexec plus
the devtmpfs, file-handle and cgroup options that the effective `.3001`
configuration lacks. Apply it through Kconfig to the dedicated 4.19 fork; do
not translate it into binary offsets.

The eventual native 6.x work uses a separate upstream-LTS fork. Port one
subsystem at a time using the 4.19 Karen behavior, the 5.10/6.x MediaTek
donors and current upstream interfaces as separate evidence layers.
