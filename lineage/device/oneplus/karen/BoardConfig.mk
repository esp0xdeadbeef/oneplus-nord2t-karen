# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/oneplus/karen

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    dtbo \
    odm \
    product \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a78

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a78

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := k6893v1_64
TARGET_NO_BOOTLOADER := true
TARGET_OTA_ASSERT_DEVICE := karen,OP557AL1

# Platform
TARGET_BOARD_PLATFORM := mt6893

# Android Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
ifeq ($(KAREN_FULL_SYSTEM),true)
BOARD_AVB_VBMETA_SYSTEM := product system system_ext
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := 1
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2
BOARD_AVB_VBMETA_VENDOR := vendor
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := 1
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 4
endif

# Boot and kernel layout, verified against CPH2399_14.0.0.3001(EX01).
BOARD_BOOT_HEADER_VERSION := 2
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_FLASH_BLOCK_SIZE := 131072

BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_RAMDISK_OFFSET := 0x11088000
BOARD_KERNEL_TAGS_OFFSET := 0x07c08000
BOARD_DTB_OFFSET := 0x07c08000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 buildvariant=user
BOARD_KERNEL_CMDLINE += androidboot.init_fatal_reboot_target=recovery
# The stock MTK bootloader omits its otherwise-correct slot argument only for
# boot-fastboot. This port deliberately supports the populated slot A only;
# keep fastbootd's boot-control and logical-partition mapping on that slot.
BOARD_KERNEL_CMDLINE += androidboot.slot_suffix=_a
ifeq ($(KAREN_DEBUG_PERMISSIVE),true)
# Private bring-up only. Release/default builds remain SELinux enforcing.
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
endif

BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# Bring-up starts with the exact stock kernel and device trees. Set
# KAREN_BUILD_SOURCE_KERNEL=true to exercise the reviewable OnePlus source.
ifeq ($(KAREN_BUILD_SOURCE_KERNEL),true)
BOARD_KERNEL_IMAGE_NAME := Image.gz
TARGET_KERNEL_SOURCE := kernel/oneplus/mt6893
TARGET_KERNEL_CONFIG := k6893v1_64_k419_defconfig
TARGET_KERNEL_CLANG_VERSION := r487747c
TARGET_KERNEL_ADDITIONAL_FLAGS := LLVM=1 LLVM_IAS=1 DEPMOD=depmod
else
TARGET_FORCE_PREBUILT_KERNEL := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
endif

BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtbs
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# Recovery lives in boot on Karen; there is no standalone recovery partition.
BOARD_USES_RECOVERY_AS_BOOT := true
TARGET_NO_RECOVERY := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6893
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT := true
TARGET_RECOVERY_UI_MARGIN_HEIGHT := 90

# Partitions
BOARD_USES_METADATA_PARTITION := true
BOARD_ROOT_EXTRA_FOLDERS += metadata
BOARD_SUPER_PARTITION_SIZE := 12348030976
BOARD_SUPER_PARTITION_GROUPS := main
# Live .3001 metadata reserves 4 MiB from super for virtual A/B metadata.
BOARD_MAIN_SIZE := 12343836672
BOARD_MAIN_PARTITION_LIST := system system_ext product vendor odm

TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
# Keep the Lineage-owned partitions writable from recovery so standard
# Lineage add-ons can be sideloaded before first boot. The reserved ext4 space
# covers the pinned Android 14 arm64 MindTheGapps payload plus filesystem
# overhead; stock-derived vendor and odm remain byte-exact EROFS images.
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 33554432
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE := 67108864
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 1342177280
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs

ifeq ($(KAREN_FULL_SYSTEM),true)
BOARD_PREBUILT_VENDORIMAGE := $(DEVICE_PATH)/prebuilt/stock/vendor.img
BOARD_PREBUILT_ODMIMAGE := $(DEVICE_PATH)/prebuilt/stock/odm.img
# The exact stock FCM extension is derived from the pinned OTA and remains an
# ignored build input. It declares optional MTK/OPlus device HALs to framework
# VINTF without copying any proprietary service into the Lineage system.
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := \
    $(abspath $(DEVICE_PATH)/prebuilt/stock-framework-vintf/compatibility_matrix.device.xml) \
    $(abspath $(DEVICE_PATH)/vintf/compatibility_matrix.karen.xml)
endif
