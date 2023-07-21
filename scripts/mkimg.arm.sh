#!/bin/sh
# shellcheck disable=all

build_rpi_blobs() {
	for i in raspberrypi-bootloader-common raspberrypi-bootloader; do
		apk fetch --quiet --stdout "$i" | tar -C "${DESTDIR}" -zx --strip=1 boot/ || return 1
	done
}

rpi_gen_cmdline() {
	echo "modules=loop,squashfs,sd-mod,usb-storage quiet modloop_verify=no ${kernel_cmdline}"
}

rpi_gen_config() {
	cat <<-EOF
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
		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		[all]
		arm_64bit=1
		dtoverlay=dwc2,dr_mode=peripheral
		include usercfg.txt
		EOF
	;;
	esac
}

build_rpi_config() {
	rpi_gen_cmdline > "${DESTDIR}"/cmdline.txt
	rpi_gen_config > "${DESTDIR}"/config.txt
}

section_rpi_config() {
	[ "$hostname" = "rpi" ] || return 0
	build_section rpi_config $( (rpi_gen_cmdline ; rpi_gen_config) | checksum )
	build_section rpi_blobs
}

profile_rpi() {
	profile_base
	title="MinKlipper for the Raspberry Pi"
	desc="Made for running Klipper on a Raspberry Pi - only essential packages are added"
	image_ext="tar.gz"
	arch="aarch64 armhf armv7"
	kernel_flavors="rpi"
	case "$ARCH" in
		aarch64) kernel_flavors="rpi rpi4";;
		armhf) kernel_flavors="rpi rpi2";;
		armv7) kernel_flavors="rpi2 rpi4";;
	esac
	kernel_cmdline="console=tty1"
	initfs_features="base squashfs mmc usb kms dhcp https"
	hostname="rpi" # Doesn't generate other boot files if changed
	apks="$apks ncurses figlet parted lsblk ca-certificates bash nano raspberrypi-bootloader python3 py3-pip newt mingetty"
	grub_mod=
}