#!/bin/bash

set -Beox pipefail

# We don't want this to be configurable anymore
# if [ -z "$1" ]; then
# 	echo "Usage: $0 <chroot directory> [optional: build]"
# 	echo "This will delete the contents of the directory you specify if it is not Alpine Linux!"
# 	echo "If the directory is Alpine Linux, then it will be chrooted into."
# 	exit 1
# fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

FOLDER="$SCRIPT_DIR/build/chroot"

sudo update-binfmts --enable

function chroot_init {
	sudo umount -lf "$FOLDER"/{proc,sys,dev} || true
	sudo mount -t proc /proc "$FOLDER"/proc/
	sudo mount --rbind /sys "$FOLDER"/sys/
	sudo mount --rbind /dev "$FOLDER"/dev/
}

function chroot_cleanup {
	sudo umount -lf "$FOLDER"/{proc,sys,dev} || echo "Unmounting failed! Please unmount $SHELL/proc, $SHELL/sys, and $SHELL/dev manually."
}

if [[ -f "$FOLDER/etc/alpine-release" ]]; then
	(
		chroot_init
		sudo cp "$SCRIPT_DIR"/scripts/* "$FOLDER"/aports/scripts
		sudo cp "$SCRIPT_DIR"/build.sh "$FOLDER"
		sudo chroot "$FOLDER" /bin/bash -c "abuild-keygen -i -a -n"
		sudo chroot "$FOLDER" /bin/bash /build.sh
		[[ "$1" == "chroot" ]] && sudo chroot "$FOLDER" /bin/bash
		sudo chmod +x "$FOLDER"/aports/scripts/*
		chroot_cleanup
	) || ( chroot_cleanup; exit 1 )
else
	(
		sudo apt -y install binfmt-support pv libarchive-tools qemu-user-static
		LATEST=$(curl -sL "https://dl-cdn.alpinelinux.org/alpine/edge/releases/aarch64/latest-releases.yaml" | grep -o -m1 'alpine-minirootfs-.*.tar.gz')
		wget "https://dl-cdn.alpinelinux.org/alpine/edge/releases/aarch64/$LATEST" -q --show-progress -O alpine.tar.gz
		mkdir -p "$FOLDER"
		rm -rf "${FOLDER:?}"/*
		pv alpine.tar.gz | sudo bsdtar -C "$FOLDER" -xp
		rm alpine.tar.gz
		sudo cp "$(which qemu-aarch64-static)" "$FOLDER"/usr/bin
		echo "nameserver 1.1.1.1" | sudo tee "$FOLDER/etc/resolv.conf"
		chroot_init
		cat <<- EOF | sudo chroot "$FOLDER" /usr/bin/qemu-aarch64-static /bin/sh
		update-ca-certificates
		apk update
		apk add git bash alpine-sdk build-base apk-tools alpine-conf busybox fakeroot xorriso squashfs-tools sudo
		git clone --depth 1 https://gitlab.alpinelinux.org/alpine/aports.git /aports
		EOF
		chroot_cleanup
		echo "Chroot sucessfully created!"
	) || ( chroot_cleanup; exit 1 )
fi
