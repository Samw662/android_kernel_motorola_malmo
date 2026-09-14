# SPDX-License-Identifier: GPL-2.0-only
# Qualcomm SDE Display DTS overlays
#
# These are compiled as .dtbo overlays and loaded at runtime.
# The DTS files include headers from this directory via relative paths.

ifeq ($(CONFIG_MMI_DEVICE_DTBS),y)

# Blair/Malmo display overlays
display-dtb-$(CONFIG_ARCH_BLAIR) += blair-sde-display-malmo-evb-overlay.dtbo

# Blair generic display overlays
display-dtb-$(CONFIG_ARCH_BLAIR) += blair-sde-display-atp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_BLAIR) += blair-sde-display-cdp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_BLAIR) += blair-sde-display-mtp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_BLAIR) += blair-sde-display-qrd-overlay.dtbo

# Kalama display overlays
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-atp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-cdp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-cdp-nfc-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-cdp-wsa883x-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-mtp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-mtp-nfc-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-qrd-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-rcm-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-hdk-overlay.dtbo
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde-display-hhg-overlay.dtbo

# Pineapple display overlays
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde-display-atp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde-display-cdp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde-display-cdp-nfc-overlay.dtbo
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde-display-mtp-overlay.dtbo
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde-display-mtp-nfc-overlay.dtbo
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde-display-qrd-overlay.dtbo
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde-display-rcm-overlay.dtbo

endif # CONFIG_MMI_DEVICE_DTBS

# Always include base SDE DTS for non-overlay builds
display-dtb-$(CONFIG_ARCH_BLAIR) += blair-sde.dtb
display-dtb-$(CONFIG_ARCH_KALAMA) += kalama-sde.dtb
display-dtb-$(CONFIG_ARCH_PINEAPPLE) += pineapple-sde.dtb

dtb-y += $(display-dtb-y)
always-y := $(dtb-y)
clean-files := *.dtb *.dtbo
