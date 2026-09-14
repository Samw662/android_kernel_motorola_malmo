# Settings for compiling waipio camera architecture
# Localized KCONFIG settings
# Camera: Remove for user build
ifneq (,$(filter userdebug eng, $(TARGET_BUILD_VARIANT)))
CONFIG_CCI_DEBUG_INTF := y
ccflags-y += -DCONFIG_CCI_DEBUG_INTF=1
endif

CONFIG_CAM_SENSOR_PROBE_RETRY := y
CONFIG_MOT_SENSOR_PRE_POWERUP := y
ccflags-y += -DCONFIG_CAM_SENSOR_PROBE_RETRY=1

ccflags-y += -DCONFIG_MOT_OIS_EARLY_UPGRADE_FW=1
ccflags-y += -DCONFIG_MOT_SENSOR_PRE_POWERUP=1