#!/bin/bash
# Re-enable the ELAN touchscreen. Run as root.
set -e

systemctl disable --now disable-elan-touchscreen.service || true
rm -f /etc/systemd/system/disable-elan-touchscreen.service
rm -f /etc/udev/rules.d/99-disable-touchscreen.rules
systemctl daemon-reload
udevadm control --reload
echo 0 > /sys/bus/usb/devices/2-1:1.0/2-1-port8/disable

echo "done. port state: $(cat /sys/bus/usb/devices/2-1:1.0/2-1-port8/state)"
