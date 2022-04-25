TARGET := iphone:clang:latest:12.0

ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = postinst prerm

postinst_FILES = main.m
postinst_CFLAGS = -fobjc-arc -I../include
postinst_CODESIGN_FLAGS = -Sentitlements.plist
postinst_INSTALL_PATH = /DEBIAN

prerm_FILES = main.m
prerm_CFLAGS = -fobjc-arc -I../include
prerm_CODESIGN_FLAGS = -Sentitlements.plist
prerm_INSTALL_PATH = /DEBIAN

include $(THEOS_MAKE_PATH)/tool.mk
