#!/bin/bash

set -ex

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Clear old builds
rm -rf "$SCRIPT_DIR"/build/{boot,overlay}/*

# Scaffold directories, if not already created
mkdir -p "$SCRIPT_DIR"/build/{boot,firmware,kernel,overlay,chroot,modloop}
mkdir -p "$SCRIPT_DIR"/build/boot/{boot,overlays}

# Overlay Setup
(
	cd "$SCRIPT_DIR"/build
	chmod +x "$SCRIPT_DIR"/overlay/etc/local.d/headless.start "$SCRIPT_DIR"/overlay/sbin/*
	cp -R "$SCRIPT_DIR"/overlay/* "$SCRIPT_DIR"/build/overlay
	git clone https://github.com/RPi-Distro/firmware-nonfree.git firmware --depth 1 || (
		[[ $? -eq 128 ]] && (cd firmware && true)
	)
	git clone https://github.com/raspberrypi/linux.git kernel --depth 1 || (
		[[ $? -eq 128 ]] && (cd kernel && true)
	)
	# Kernel Configuration and Compilation
	(
		cd kernel
		if [[ ! -f .config ]]; then
			echo "What aarch64 defconfig would you like to use?"
			echo "Options include,"
			echo "bcm2711_defconfig - Default for any aarch64 device"
			echo "bcmrpi3_defconfig - Slimmed down for Pi 3 Boards -> Pi 3 or Zero 2 (RP30AU)"
			echo "defconfig         - Default aarch64 Pi defconfig (I haven't seen this be used)"
			read -r DEFCONFIG
			make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$DEFCONFIG"
		fi
		# read -p "Would you like to configure the kernel further? " -n 1 -r
		# if [[ $REPLY =~ ^[Yy]$ ]]; then
		# 	make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
		# fi
		make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image modules dtbs
		# Kernel
		cp arch/arm64/boot/Image "$SCRIPT_DIR"/build/boot/boot/vmlinuz-rpi
		# DTBs
		cp arch/arm64/boot/dts/broadcom/*.dtb "$SCRIPT_DIR"/build/boot/
		cp arch/arm64/boot/dts/overlays/*.dtb* "$SCRIPT_DIR"/build/boot/overlays/
		cp arch/arm64/boot/dts/overlays/README "$SCRIPT_DIR"/build/boot/overlays/
		# Config
		cp .config "$SCRIPT_DIR"/build/boot/boot/config-rpi
	)
	# Modules
	(
		cd kernel
		make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH="$SCRIPT_DIR"/build/overlay modules_install
	)
	# Firmware
	(
		cd firmware
		mkdir -p "$SCRIPT_DIR"/build/overlay/lib/firmware/brcm
		cp -R debian/config/brcm80211/brcm/* "$SCRIPT_DIR"/build/overlay/lib/firmware/brcm/
	)
	# Modloop
	(
		cd modloop
		rm -rf ./*
		bsdtar -O -xf "$SCRIPT_DIR"/alpine.tar.gz boot/modloop-rpi > modloop-old
		unsquashfs -f -d modloop modloop-old
		cp -R "$SCRIPT_DIR"/build/overlay/lib/modules/* modloop/modules
		mksquashfs modloop modloop-rpi -comp xz -noappend -Xbcj arm,armthumb -Xdict-size 100%
		cp modloop-rpi "$SCRIPT_DIR"/build/boot/boot/modloop-rpi
	)
	# Archive the overlay
	(
		cd overlay
		tar czvf "$SCRIPT_DIR"/headless.apkovl.tar.gz --owner=0 --group=0 -- *
	)
)