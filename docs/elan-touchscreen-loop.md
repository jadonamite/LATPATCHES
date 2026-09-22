# ELAN touchscreen re-enumeration loop (Latitude E7440)

Status: **fixed** 2026-09-22 07:43:45

## Symptom

Pointer and keyboard input intermittently stall. A click or keypress is
swallowed; input recovers on its own after a few seconds, then stalls again.

The workaround that appeared to fix it:

    sudo modprobe -r psmouse && sudo modprobe psmouse

This is misleading. It tears down and recreates the PS/2 touchpad's input
node, which pushes it back to the front of the input stack. The actual fault
is on a different device entirely.

## Root cause

The internal ELAN touchscreen digitizer (USB `04f3:0111`, hardwired to port
`2-1.8` on the EHCI hub) disconnects and re-enumerates roughly every 2.5
seconds, continuously, from boot:

    usb 2-1.8: USB disconnect, device number 42
    usb 2-1.8: new full-speed USB device number 43 using ehci-pci
    usb 2-1.8: New USB device found, idVendor=04f3, idProduct=0111
    ... repeating

Re-enumerations per boot, from `journalctl -k -b <n> | grep -c "ELAN Touchscreen] on usb"`:

| Boot        | Count  |
|-------------|--------|
| Sep 20      | 22702  |
| Sep 22 (1)  | 610    |
| Sep 22 (2)  | 128 in 5 min |

Each cycle fires a full udev and libinput device re-probe. Input handling
stalls under that load. The input device counter had climbed past `input2135`
on a machine that enumerates 14 devices at boot.

The digitizer is failing at the hardware level — a cracked panel or a loose
ribbon, common on this chassis. No software change repairs it.

## Why deauthorizing was not enough

An earlier attempt set `authorized=0` on the device:

    SUBSYSTEM=="usb", ATTRS{idVendor}=="04f3", ATTRS{idProduct}=="0111", ATTR{authorized}="0"

Two problems.

`ATTRS{}` walks the parent chain, so the rule also matches the USB *interface*
(`2-1.8:1.0`), which has no writable `authorized`. Every re-enumeration logged:

    Failed to write ATTR{/sys/.../2-1.8:1.0/authorized}, ignoring: No such file or directory

More importantly, deauthorization works — `authorized` read back as `0` — and
the loop continued anyway. Deauthorizing stops the kernel binding a driver; it
does not stop the port cycling. The port itself has to go.

## Fix

Disable the hub port. `connect_type` is `hardwired`, so nothing else can ever
appear there.

    echo 1 > /sys/bus/usb/devices/2-1:1.0/2-1-port8/disable

The sysfs write does not survive a reboot, so `disable-elan-touchscreen.service`
reapplies it at every boot. The udev rule is kept as a second layer, corrected
to match `DEVTYPE=="usb_device"` with `ATTR{}` so it stops spamming errors.

Install:

    sudo ./patches/elan-touchscreen/install.sh

## Verification

    $ cat /sys/bus/usb/devices/2-1:1.0/2-1-port8/disable
    1
    $ cat /sys/bus/usb/devices/2-1:1.0/2-1-port8/state
    not attached
    $ ls /sys/bus/usb/devices/2-1.8
    ls: cannot access ...: No such file or directory
    $ journalctl -k --since "07:45" | grep -c "2-1.8"
    0

Last kernel event from the device was 07:43:45, the moment the port was
disabled. Zero since.

## Reversal

    sudo ./patches/elan-touchscreen/uninstall.sh

## Environment

    Dell Latitude E7440, BIOS A21
    Ubuntu 24.04.4 LTS, kernel 7.0.0-31-generic
    Touchscreen: ELAN 04f3:0111 at usb-0000:00:1d.0-1.8
