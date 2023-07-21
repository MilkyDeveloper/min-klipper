#!/bin/bash
# This is run in the chroot - do not run it manually
apk update
bash aports/scripts/mkimage.sh --tag edge --outdir /output --arch aarch64 --repository http://dl-cdn.alpinelinux.org/alpine/edge/main --extra-repository http://dl-cdn.alpinelinux.org/alpine/edge/community --profile rpi