#!/bin/bash
# Disable a failing ELAN touchscreen (04f3:0111) on a Dell Latitude E7440.
# Run as root. See ../../docs/elan-touchscreen-loop.md for the diagnosis.
set -e

HUB_PORT=/sys/bus/usb/devices/2-1:1.0/2-1-port8/disable
HERE=$(dirname "$(readlink -f "$0")")

if [ ! -w "$HUB_PORT" ]; then
    echo "error: $HUB_PORT not writable (run as root; verify the port path)" >&2
    exit 1
fi

echo 1 > "$HUB_PORT"
install -m 0644 "$HERE/99-disable-touchscreen.rules" /etc/udev/rules.d/
install -m 0644 "$HERE/disable-elan-touchscreen.service" /etc/systemd/system/

udevadm control --reload
systemctl daemon-reload
systemctl enable --now disable-elan-touchscreen.service

echo "done. port state: $(cat /sys/bus/usb/devices/2-1:1.0/2-1-port8/state)"
