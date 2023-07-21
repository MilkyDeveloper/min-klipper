#!/bin/bash

set -e

# Intended to be run as a login program by mingetty

# mingetty will restart the script if it exits
[[ -f /tmp/minklipper-install-failed ]] && exit

# We don't want to start installing before the user is viewing the serial connection
if ! whiptail --title "MinKlipper Installer" --yesno "Installation will take less than 10 minutes.\n\nReady to install MinKlipper?" 9 78; then
	echo "You can run \"exit\" to restart the installer."
	bash
	# Restart the script when the user exits the shell
	bash "$(basename "$0")"
fi

if /sbin/minklipper.sys-install; then
	whiptail --title "MinKlipper Installer" --msgbox "Installation succeeded!\n\nPlug in your device into your printer. Press OK to shutdown." 9 78
	poweroff
else
	touch /tmp/minklipper-install-failed
	whiptail --title "MinKlipper Installer" --msgbox "Installation failed!\n\nPlease file an issue on Github and attach all text logged above." 9 78
fi