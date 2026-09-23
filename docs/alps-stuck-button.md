# ALPS DualPoint touchpad: BTN_RIGHT stuck pressed

Status: **mitigated** 2026-09-23 — underlying hardware fault unrepaired

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

## Masking the button

Masking button 3 keeps the touchpad usable and stops the grab:

    xinput set-button-map <id> 1 2 0 4 5 6 7

The obstacle is that X rejects a button-map change with `MappingBusy` while a
button on the device is held — and this one is held permanently. Applied
directly it fails silently through `xinput`; the map simply reads back
unchanged.

The way around it is to disable the device first. That clears X's view of the
button state, the map is applied in that window, and the device is re-enabled
with the mask in place:

    gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled
    xinput set-button-map <id> 1 2 0 4 5 6 7
    gsettings set org.gnome.desktop.peripherals.touchpad send-events enabled

The touchpad keeps pointing, tap-to-click and two-finger scroll. Only the
right button — already useless — is lost. Right-click remains available on
the TrackPoint buttons and any external mouse.

Verified over 10 samples at 2s intervals with the touchpad enabled: the
touchpad reports no buttons down and the master pointer holds no grab.

### Persistence

The map lives on the X device, so it is lost whenever the device is recreated
— at login, and on every `psmouse` reload. At session start the button is
already stuck, so a plain remap would hit `MappingBusy` again; the disable and
re-enable steps are what make it reliable there.

`patches/alps-stuck-button/mask-stuck-button.sh` performs the sequence and
verifies the resulting map. It is installed to `~/.local/bin` and run by a
systemd user unit bound to `graphical-session.target`:

    systemctl --user enable --now mask-stuck-button.service

Re-run it by hand after any `psmouse` reload.

## Earlier mitigation: disabling the touchpad

Before the mask was found to work, the touchpad was disabled outright:

    gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled

This is still the fallback if the mask ever fails — it makes the grab
structurally impossible, at the cost of all touchpad input. Pointing then
falls to the TrackPoint stick, which reads clean across all 7 of its buttons,
or an external mouse.

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
