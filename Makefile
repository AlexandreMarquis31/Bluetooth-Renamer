ARCH = armv7 arm64
TARGET= iphone:9.2
include ~/theos/makefiles/common.mk

TWEAK_NAME = BluetoothRename
BluetoothRename_FILES = Tweak.xm
BluetoothRename_FRAMEWORKS = UIKit AppSupport
BluetoothRename_LIBRARIES = rocketbootstrap
BluetoothRename_LDFLAGS += -Wl,-segalign,4000
BluetoothRename_PRIVATE_FRAMEWORKS = Preferences FrontBoard
Depends:  com.rpetrich.rocketbootstrap
include $(THEOS_MAKE_PATH)/tweak.mk
after-install::
	install.exec "killall -9 SpringBoard"
