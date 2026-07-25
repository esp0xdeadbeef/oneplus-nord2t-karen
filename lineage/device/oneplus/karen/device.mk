# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/oneplus/karen

$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := false

ifneq ($(strip $(KAREN_DEBUG_ADB_KEYS)),)
# Opt-in headless bring-up access. Point this at one local Android public key;
# never copy the key into the device tree or enable this for release images.
PRODUCT_ADB_KEYS := $(strip $(KAREN_DEBUG_ADB_KEYS))
endif

ifeq ($(KAREN_FULL_SYSTEM),true)
# The pinned stock vendor requires the Android 12 VNDK snapshot. Android 14
# no longer enables legacy VNDK snapshots by default.
PRODUCT_EXTRA_VNDK_VERSIONS += 31
endif

PRODUCT_PACKAGES += \
    android.hardware.boot-service.default_recovery \
    fastbootd \
    fstab.mt6893.first_stage_ramdisk \
    fstab.mt6893.ramdisk \
    init.recovery.mt6893.rc \
    snapuserd_ramdisk

PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml
