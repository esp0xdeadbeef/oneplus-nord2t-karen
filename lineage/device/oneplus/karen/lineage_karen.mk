# SPDX-License-Identifier: Apache-2.0

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/oneplus/karen/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_karen
PRODUCT_DEVICE := karen
PRODUCT_BRAND := OnePlus
PRODUCT_MODEL := CPH2399
PRODUCT_MANUFACTURER := OnePlus

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="CPH2399EEA-user 12 SKQ1.211019.001 S.202606160204 release-keys" \
    BuildFingerprint=OnePlus/CPH2399EEA/OP557AL1:12/SKQ1.211019.001/S.202606160204:user/release-keys \
    DeviceName=OP557AL1 \
    ProductName=CPH2399EEA

TARGET_BOOT_ANIMATION_RES := 1080
