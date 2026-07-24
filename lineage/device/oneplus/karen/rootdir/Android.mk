# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),karen)

include $(CLEAR_VARS)
LOCAL_MODULE := fstab.mt6893.ramdisk
LOCAL_MODULE_STEM := fstab.mt6893
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := etc/fstab.mt6893
LOCAL_MODULE_PATH := $(TARGET_RAMDISK_OUT)/system/etc
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := fstab.mt6893.first_stage_ramdisk
LOCAL_MODULE_STEM := fstab.mt6893
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := etc/fstab.mt6893
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/first_stage_ramdisk
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := init.recovery.mt6893.rc
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := etc/init.recovery.mt6893.rc
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)
include $(BUILD_PREBUILT)

endif
