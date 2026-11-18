export ARCHS = arm64
export TARGET = iphone:clang:12.4:12.0
export _THEOS_PLATFORM_DPKG_DEB_COMPRESSION = gzip
export THEOS_PLATFORM_DEB_COMPRESSION_TYPE = gzip

INSTALL_TARGET_PROCESSES = Camera

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PhotographicStyles12

PhotographicStyles12_FILES = Tweak.xm \
	Core/PSState.m \
	Core/PSColorProfile.m \
	Core/PSColorEngine.m \
	Core/PSPreviewFilterController.m \
	Captures/PSCaptureCoordinator.m \
	Captures/PSStillImageBaker.m \
	Captures/PSLivePhotoVideoBaker.m \
	UI/PSTopBarButton.m \
	UI/PSMatrixPadView.m \
	UI/PSPaletteSliderView.m \
	UI/PSPresetStripView.m \
	UI/PSStyleControlPanel.m \
	UI/PSOverlayPassthroughView.m

PhotographicStyles12_CFLAGS = -fobjc-arc -fno-modules -Wall -Wextra -Werror \
	-Wno-unused-parameter -Wno-deprecated-declarations -Wno-deprecated-module-dot-map \
	-I$(THEOS_PROJECT_DIR)/Headers \
	-I$(THEOS_PROJECT_DIR)/Core \
	-I$(THEOS_PROJECT_DIR)/Captures \
	-I$(THEOS_PROJECT_DIR)/UI

PhotographicStyles12_FRAMEWORKS = Foundation UIKit QuartzCore CoreGraphics CoreImage CoreMedia ImageIO AVFoundation
PhotographicStyles12_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Camera 2>/dev/null || true"
