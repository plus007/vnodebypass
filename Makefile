ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME = vnodebypass

vnodebypass_FILES = main.m offsets.m
vnodebypass_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk

internal-stage::
	$(ECHO_NOTHING)ldid -S$(THEOS_STAGING_DIR)/../../tfp0.plist $(THEOS_STAGING_DIR)/usr/bin/vnodebypass$(ECHO_END)
	$(ECHO_NOTHING)chown 0:0 $(THEOS_STAGING_DIR)/usr/bin/vnodebypass$(ECHO_END)
	$(ECHO_NOTHING)chmod 6755 $(THEOS_STAGING_DIR)/usr/bin/vnodebypass$(ECHO_END)