#!/bin/sh

build_minklipper_blobs() {
	for i in raspberrypi-bootloader-common raspberrypi-bootloader; do
		apk fetch --quiet --stdout "$i" | tar -C "${DESTDIR}" -zx --strip=1 boot/ || return 1
	done
}

minklipper_gen_cmdline() {
	echo "modules=loop,squashfs,sd-mod,usb-storage quiet ${kernel_cmdline}"
}

minklipper_gen_config() {
	cat <<- EOF
	# do not modify this file as it will be overwritten on upgrade.
	# create and/or modify usercfg.txt instead.
	# https://www.raspberrypi.com/documentation/computers/config_txt.html
	EOF
	case "$ARCH" in
	armhf)
		cat <<-EOF
		[pi0]
		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		[pi0w]
		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		[pi1]
		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		[pi02]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[pi2]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[pi3]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[pi3+]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[all]
		dtoverlay=dwc2,dr_mode=peripheral
		include usercfg.txt
		EOF
	;;
	armv7)
		cat <<-EOF
		[pi02]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[pi2]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[pi3]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[pi3+]
		kernel=boot/vmlinuz-rpi2
		initramfs boot/initramfs-rpi2
		[pi4]
		kernel=boot/vmlinuz-rpi4
		initramfs boot/initramfs-rpi4
		[all]
		dtoverlay=dwc2,dr_mode=peripheral
		include usercfg.txt
		EOF
	;;
	aarch64)
		cat <<-EOF
		[pi02]
		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		[pi3]
		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		[pi3+]
		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		[pi4]
		enable_gic=1
		kernel=boot/vmlinuz-rpi4
		initramfs boot/initramfs-rpi4
		[all]
		arm_64bit=1
		dtoverlay=dwc2,dr_mode=peripheral
		include usercfg.txt
		EOF
	;;
	esac
}

build_minklipper_config() {
	minklipper_gen_cmdline > "${DESTDIR}"/cmdline.txt
	minklipper_gen_config > "${DESTDIR}"/config.txt
}

section_minklipper_config() {
	[ "$hostname" = "rpi" ] || return 0
	build_section minklipper_config $( (minklipper_gen_cmdline ; minklipper_gen_config) | checksum )
	build_section minklipper_blobs
}

profile_minklipper() {
	profile_base
	title="Minklipper for Raspberry Pi"
	desc="Includes Raspberry Pi kernel.
			Designed for RPI 1, 2, 3 and 4.
			Amended for the easy installation of Klipper"
	image_ext="tar.gz"
	arch="aarch64 armhf armv7"
	kernel_flavors="rpi"
	case "$ARCH" in
		aarch64) kernel_flavors="rpi rpi4";;
		armhf) kernel_flavors="rpi rpi2";;
		armv7) kernel_flavors="rpi2 rpi4";;
	esac
	kernel_cmdline="console=tty1 modules-load=dwc2"
	initfs_features="base squashfs mmc usb kms dhcp https"
	hostname="minklipper"
	grub_mod=
	apks="$apks ncurses parted lsblk ca-certificates bash nano raspberrypi-bootloader"
}