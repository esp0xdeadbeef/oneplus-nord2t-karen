#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

"""Launch MTKClient GUI with the safe Karen connection defaults.

This only changes connection setup: skip the watchdog register write that hangs
the OPlus preloader, and preload the device-specific preloader plus a DA file.
It does not initiate any flash operation.
"""

from __future__ import annotations

import os
from pathlib import Path

import mtkclient.mtk_gui as gui


def required_file(variable: str) -> Path:
    value = os.environ.get(variable)
    if not value:
        raise SystemExit(f"{variable} is required")
    path = Path(value)
    if not path.is_file():
        raise SystemExit(f"{variable} does not exist: {path}")
    return path


preloader = required_file("KAREN_MTK_PRELOADER")
da_value = os.environ.get("KAREN_MTK_DA")
da = Path(da_value) if da_value else None
if da is not None and not da.is_file():
    raise SystemExit(f"KAREN_MTK_DA does not exist: {da}")
serial_setting = os.environ.get("KAREN_MTK_SERIAL", "USB")
serial_port = None if serial_setting in ("", "USB") else serial_setting
original_device_handler = gui.DeviceHandler


class KarenDeviceHandler(original_device_handler):
    def __init__(self, parent, loglevel=gui.logging.INFO, *args, **kwargs):
        kwargs.pop("preloader", None)
        kwargs.pop("loader", None)
        gui.QObject.__init__(self, parent, *args, **kwargs)
        config = gui.MtkConfig(
            loglevel=gui.logging.INFO,
            gui=self.sendToLogSignal,
            guiprogress=self.sendToProgressSignal,
            update_status_text=self.update_status_text,
        )
        config.gpt_settings = gui.GptSettings(
            gpt_num_part_entries="0",
            gpt_part_entry_size="0",
            gpt_part_entry_start_lba="0",
        )
        config.reconnect = True
        config.uartloglevel = 2
        config.skipwdt = True
        config.loader = str(da) if da is not None else None
        config.preloader_filename = str(preloader)
        config.preloader = preloader.read_bytes()
        config.write_preloader_to_file = False
        self.loglevel = gui.logging.DEBUG
        self.da_handler = gui.DaHandler(
            gui.Mtk(
                config=config,
                loglevel=gui.logging.INFO,
                serialportname=serial_port,
            ),
            loglevel,
        )


gui.DeviceHandler = KarenDeviceHandler
raise SystemExit(gui.main())
