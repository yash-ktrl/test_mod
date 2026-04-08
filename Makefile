INSTALL_TARGET_PROCESSES = SmashKarts

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SmashKartsFOV

SmashKartsFOV_FILES = SmashKartsFOV.m
SmashKartsFOV_CFLAGS = -fobjc-arc
SmashKartsFOV_LIBRARIES = substrate

# Target iOS arm64
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS_MAKE_PATH)/tweak.mk
