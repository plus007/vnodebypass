TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = vnodebypass

ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = vnodebypass

vnodebypass_FILES = main.m AppDelegate.m RootViewController.m
vnodebypass_FRAMEWORKS = UIKit CoreGraphics
vnodebypass_CFLAGS = -fobjc-arc -I../include
vnodebypass_CODESIGN_FLAGS = -Sappent.xml

include $(THEOS_MAKE_PATH)/application.mk
