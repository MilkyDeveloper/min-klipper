#!/bin/bash

# Exit on errors and produce verbose output
set -ex

# Variables
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SIZE="4G"
IMG="min-klipper.img"

# Change directory to the script location
cd "$SCRIPT_DIR"

# Dependencies
sudo apt install -y util-linux parted dosfstools pv libarchive-tools nano \
					git bc bison flex libssl-dev make libc6-dev libncurses5-dev \
					crossbuild-essential-arm64 gcc-aarch64-linux-gnu

# Clear old builds
[[ -f "$IMG" ]] && rm "$IMG"

# Create an empty 4G image
fallocate -l "$SIZE" "$IMG"

# Mount the image
USB=$(sudo losetup -f --show "$IMG")

# Partition it!

# Clean GPT Partition Table
sudo parted -s "$USB" mklabel msdos
# Empty 256MB kernel partition
sudo parted "$USB" -s mkpart primary fat32 0% 512MB
sudo parted "$USB" set 1 boot on
# Root Partition occupying the rest
# sudo parted -s -a optimal $USB unit mib mkpart Root 256 100%
sudo parted "$USB" -s mkpart primary ext4 512MB 100%

sync # Commit changes

# Format the kernel partition as FAT32
yes | sudo mkfs.vfat -F 32 "${USB}"p1 -n "MINKLIPPER"

# Format the root partition as ext4
yes | sudo mkfs.ext4 "${USB}"p2

sync # Commit changes

# Mount the boot partition
sudo umount _boot || true
rm -rf _boot
mkdir _boot
sudo mount "${USB}p1" _boot

# LATEST=$(curl -sL "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/latest-releases.yaml" | grep -o -m1 'alpine-rpi-.*.tar.gz')
# wget "https://dl-cdn.alpinelinux.org/alpine/edge/releases/aarch64/$LATEST" -q --show-progress -O alpine.tar.gz

# Build the initramfs
bash chrootstrap.sh
cp build/chroot/output/alpine-rpi-edge-aarch64.tar.gz alpine.tar.gz

# Zip the rootfs
(
	cd overlay
	tar czvf ../headless.apkovl.tar.gz --owner=0 --group=0 -- *
)

# Extract the rootfs
pv alpine.tar.gz | sudo bsdtar -C _boot -xp

# Build the overlay
# [[ -f overlay.config.mine ]] || (
# 	echo "overlay.config will be opened in nano. Please configure network access."
# 	sleep 5
# 	nano overlay.config
# )

# We don't need a custom kernel anymore
# My config changes have been mainlined
# -- OVERLAY --
# bash make-overlay.sh || ( echo "Could not build overlay - see make-overlay.sh for more information"; exit 1 )
# -- OVERLAY --

sudo cp headless.apkovl.tar.gz _boot/headless.apkovl.tar.gz
sudo cp overlay.config _boot/overlay.config
sudo cp overlay.config.mine _boot/overlay.config || ( echo "Ignore the error above"; true )
# echo "dtoverlay=dwc2" | sudo tee -a _boot/config.txt
# echo -n "modules-load=dwc2" | sudo tee -a _boot/cmdline.txt

sync # Commit changes

# Unmount the boot partition
sudo umount _boot
rm -rf _boot

sync # Commit changes

# Unmount the image
sudo losetup -d "$USB"