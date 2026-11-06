TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = VideoStar

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VideoStarRecorder

VideoStarRecorder_FILES = VSPassthroughWindow.m VSFloatingButton.m VSMacroEngine.m Tweak.xm
VideoStarRecorder_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function
VideoStarRecorder_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
