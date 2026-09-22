# ALPS DualPoint touchpad: BTN_RIGHT stuck pressed

Status: **open** — hardware fault, no software fix

## Symptom

Clicks stop registering. Buttons in applications do nothing. The keyboard
still works, so the desktop is reachable via shortcuts. Recovering requires:

    sudo modprobe -r psmouse && sudo modprobe psmouse

which restores clicking for seconds to minutes before it fails again.

Reloads on 2026-09-22: 07:51:45, 07:54:07, 07:59:40, 08:19:26, 08:33:29.

This looks identical to the ELAN touchscreen loop documented separately, and
was initially mistaken for it. It is a second, unrelated fault. The touchscreen
fix is verified and did not resolve this.

## Root cause

The touchpad's right button is asserted continuously at the hardware level.

X's view:

    $ xinput --query-state "AlpsPS/2 ALPS DualPoint TouchPad"
        button[3]=down

The kernel agrees, read directly via `EVIOCGKEY` on the evdev node
(see `tools/btncheck.sh`):

    kernel says BTN_LEFT    = released
    kernel says BTN_RIGHT   = PRESSED
    kernel says BTN_MIDDLE  = released

Sampled every 2s for 20s with the touchpad untouched: `DOWN` on all 10
samples. Not intermittent, and not a lost release event — the hardware
asserts it continuously.

The DualPoint Stick is a separate input device on the same serio port and
reads clean across all 7 of its buttons. Only the lower touchpad button pair
is affected.

## Why the psmouse reload appears to work

A held button makes X open an implicit pointer grab: every subsequent pointer
event routes to the window that owns the phantom press, so clicks elsewhere go
nowhere. Keyboard input is unaffected, which is why shortcuts still work.

Reloading psmouse destroys the input device, which forces X to drop the grab.
The driver then re-initializes, re-reads the hardware, finds the button still
asserted, and the grab reforms. Measured: stuck again 26 seconds after the
08:33:29 reload.

Each reload also creates a new X device id — the touchpad went from `input6`
at boot to `input2158` — so per-device settings reset, and any `xinput`-based
workaround is lost.

## Why button remapping does not work

Masking button 3 is the obvious mitigation:

    xinput set-button-map <id> 1 2 0 4 5 6 7

X rejects it with `MappingBusy` while a button on the device is held. The
button map cannot be changed precisely because the button is stuck. The call
fails silently through `xinput` — the map simply reads back unchanged.

## Mitigation

Disable the touchpad and drive the machine from the TrackPoint stick or an
external mouse:

    gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled

This survives reboots and psmouse reloads, since GNOME reapplies it per-device
as devices appear. Reverse with `send-events enabled`.

## Repair

Likely a worn or obstructed button mechanism. On a chassis of this age, also
check for a swollen battery pressing up into the palmrest — signs are the
laptop rocking on a flat surface, a raised or stiff touchpad, or opened case
seams. This unit's battery is at 71.3% of design capacity (33.77 of 47.36 Wh),
consistent with age but not on its own evidence of swelling.

## Environment

    Dell Latitude E7440, BIOS A21
    Ubuntu 24.04.4 LTS, kernel 7.0.0-31-generic
    Touchpad: AlpsPS/2 ALPS DualPoint TouchPad at isa0060/serio1/input0
    Session: X11
