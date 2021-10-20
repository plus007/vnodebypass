GO_EASY_ON_ME = 1
DEBUG=0
FINALPACKAGE=1

THEOS_DEVICE_IP = 0.0.0.0 -p 2222

TARGET := iphone:clang:14.0:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = vnodebypass

vnodebypass_FILES = main.m vnode.m libdimentio.c kernel.m
vnodebypass_CFLAGS = -fobjc-arc
vnodebypass_CODESIGN_FLAGS = -Sent.plist
vnodebypass_INSTALL_PATH = /usr/bin
vnodebypass_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tool.mk

before-package::
	chmod 6755 $(THEOS_STAGING_DIR)/usr/bin/vnodebypass
	chmod 755 $(THEOS_STAGING_DIR)/Applications/vnodebypass.app/vnodebypass
	ldid -Sappent.xml $(THEOS_STAGING_DIR)/Applications/vnodebypass.app/vnodebypass
