#!/bin/bash
# Mask the stuck BTN_RIGHT on the ALPS DualPoint touchpad so it cannot hold
# an X pointer grab, while keeping the touchpad usable for pointing.
#
# X rejects a button-map change with MappingBusy while a button on the device
# is held -- and this one is held permanently by a hardware fault. The dance
# below works around that: disabling the device clears X's view of the button,
# the map is applied in that window, then the device is re-enabled.
#
# See docs/alps-stuck-button.md.
set -u

DEVICE="AlpsPS/2 ALPS DualPoint TouchPad"
SCHEMA=org.gnome.desktop.peripherals.touchpad
export DISPLAY="${DISPLAY:-:0}"

# Wait for the device to exist (session start races device creation).
for _ in $(seq 1 30); do
    ID=$(xinput list --id-only "$DEVICE" 2>/dev/null | head -1)
    [ -n "${ID:-}" ] && break
    sleep 1
done

if [ -z "${ID:-}" ]; then
    echo "mask-stuck-button: touchpad not found, giving up" >&2
    exit 1
fi

gsettings set $SCHEMA send-events disabled
sleep 1
xinput set-button-map "$ID" 1 2 0 4 5 6 7
gsettings set $SCHEMA send-events enabled
sleep 1

MAP=$(xinput get-button-map "$ID" 2>/dev/null)
case "$MAP" in
    "1 2 0 4 5 6 7 ") echo "mask-stuck-button: ok (device $ID, map: $MAP)" ;;
    *) echo "mask-stuck-button: FAILED (device $ID, map: $MAP)" >&2; exit 1 ;;
esac
