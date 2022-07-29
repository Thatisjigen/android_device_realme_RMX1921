#
# Copyright (C) 2022 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Inherit from RMX1921 device
$(call inherit-product, device/realme/RMX1921/device.mk)

PRODUCT_NAME := lineage_RMX1921
PRODUCT_DEVICE := RMX1921
PRODUCT_MANUFACTURER := oplus
PRODUCT_BRAND := realme
PRODUCT_MODEL := RMX1921

PRODUCT_GMS_CLIENTID_BASE := android-oppo

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="sargo-user 12 SP2A.220405.003 8210211 release-keys"

BUILD_FINGERPRINT := google/sargo/sargo:12/SP2A.220405.003/8210211:user/release-keys
