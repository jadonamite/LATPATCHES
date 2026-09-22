# LATPATCHES

Hardware fault diagnoses and fixes for a Dell Latitude E7440 running
Ubuntu 24.04 LTS.

Each entry records the symptom, the evidence that identified the cause, the
fix, how to verify it, and how to undo it.

## Patches

| Issue | Status | Document |
|---|---|---|
| ELAN touchscreen re-enumerating every ~2.5s, stalling all input | fixed | [docs/elan-touchscreen-loop.md](docs/elan-touchscreen-loop.md) |
| ALPS touchpad BTN_RIGHT stuck pressed, killing clicks | open, hardware | [docs/alps-stuck-button.md](docs/alps-stuck-button.md) |

Both faults present the same way — input stops responding, and reloading
`psmouse` appears to fix it. They have nothing to do with `psmouse`, and
nothing to do with each other.

## Layout

    docs/                        diagnosis and fix write-ups
    patches/elan-touchscreen/    udev rule, systemd unit, install/uninstall
    tools/btncheck.sh            read evdev button state straight from the kernel

## Applying

    sudo ./patches/elan-touchscreen/install.sh

The USB port path in that patch (`2-1:1.0/2-1-port8`) is specific to this
machine's internal digitizer. Confirm the port on yours before running it.
