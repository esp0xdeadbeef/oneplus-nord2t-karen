<!-- SPDX-License-Identifier: MIT -->

# Karen DTB patches

Store ordered, reviewable patches against `a/karen.dts` here.

The directory deliberately starts without a device patch. Before adding one,
derive and compare:

- the base DTB from the pinned `.3001` `boot.img`;
- the pinned `.3001` DTBO;
- the live flattened device tree after bootloader fixups.

A patch must cite that evidence and must not invent register addresses,
interrupts, reserved memory or firmware names. Generated `.dtb`, `.dts` and
stock-derived files remain build outputs and must not be committed.
