#!/bin/bash
# Ask the KERNEL whether the touchpad's right button is physically pressed.
EV=$(grep -A8 "ALPS DualPoint TouchPad" /proc/bus/input/devices | grep -m1 -o "event[0-9]*")
echo "touchpad node: /dev/input/$EV"
python3 - "/dev/input/$EV" <<'PY'
import fcntl, sys, array
BTN_LEFT, BTN_RIGHT, BTN_MIDDLE = 0x110, 0x111, 0x112
EVIOCGKEY = (2 << 30) | (ord('E') << 8) | 0x18 | (96 << 16)
buf = array.array('B', [0] * 96)
with open(sys.argv[1], 'rb') as f:
    fcntl.ioctl(f, EVIOCGKEY, buf, True)
def pressed(code):
    return bool(buf[code // 8] & (1 << (code % 8)))
for name, code in (("BTN_LEFT", BTN_LEFT), ("BTN_RIGHT", BTN_RIGHT), ("BTN_MIDDLE", BTN_MIDDLE)):
    print(f"  kernel says {name:<11} = {'PRESSED' if pressed(code) else 'released'}")
PY
echo "--- X's view ---"
DISPLAY=:0 xinput --query-state "AlpsPS/2 ALPS DualPoint TouchPad" 2>/dev/null | grep -E "button\[[0-9]+\]=down" || echo "  (X: no buttons down)"
