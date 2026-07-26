# SPDX-License-Identifier: MIT
let
  family = import ./families/mt6893;
  device = import ./devices/oneplus-karen;
in
  assert device.family == family.name;
  assert device.hardware.architecture == family.architecture;
  assert device.stock.boot.size == device.bootImage.partitionSize;
  assert device.bootImage.headerVersion == 2;
  assert device.bootImage.pageSize == 2048; {
    schemaVersion = 1;
    inherit device family;
  }
