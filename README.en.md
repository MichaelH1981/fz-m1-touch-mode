# Panasonic FZ-M1 MK3 touch and passive stylus modes on Linux

[Deutsche Fassung](README.md)

> **Authorship:** Research, static analysis, protocol reconstruction,
> implementation, testing, and documentation were performed by **OpenAI Codex**
> at Michael Hartlapp's request. Michael provided the test hardware and authorized
> and supervised the work performed on the device.

This project switches the Sharp `04dd:9762` touchscreen controller in a Panasonic
Toughpad FZ-M1 MK3 to Panasonic's original **Pen/Touch mode**, without Windows.
It also supports the Touch, Pen, Glove, and Water/Rain profiles.

## Why this is needed

Linux's `hid-multitouch` driver handles this device's ordinary multitouch reports.
The HID descriptor has no separate stylus collection, however. Panasonic's passive
stylus is enabled by the operating mode stored in the Sharp controller, not by an
additional Linux pen driver. The tested tablet was initially in Water mode (`0x0a`).

Panasonic's Windows software changes the mode through vendor-defined HID reports.
The included tool implements only commands and values recovered by static analysis
of Panasonic's exact FZ-M1 MK3 package and subsequently verified by controlled
readback on the real device. No Windows executable or firmware updater was run.

## Usage

Inspect the current mode and known registers:

```sh
sudo /usr/local/sbin/fz-m1-touch-mode status
sudo /usr/local/sbin/fz-m1-touch-mode registers
```

Select a profile:

```sh
sudo /usr/local/sbin/fz-m1-touch-mode touch
sudo /usr/local/sbin/fz-m1-touch-mode pen
sudo /usr/local/sbin/fz-m1-touch-mode pen-touch
sudo /usr/local/sbin/fz-m1-touch-mode glove
sudo /usr/local/sbin/fz-m1-touch-mode water
```

Every changed mode and register is read back before the command reports success. If
application fails, the tool attempts to restore the previous mode and affected
values.

## Installation

```sh
sudo install -o root -g root -m 0755 tools/fz-m1-touch-mode /usr/local/sbin/
sudo install -o root -g root -m 0644 systemd/fz-m1-touch-mode@.service /etc/systemd/system/
sudo install -o root -g root -m 0644 udev/99-fz-m1-touch-mode.rules /etc/udev/rules.d/
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo udevadm trigger --action=add --subsystem-match=hidraw
```

The udev rule matches only USB VID/PID `04dd:9762` and starts the corresponding
systemd instance for the dynamically assigned hidraw node. A real reboot test passed
when the device changed from `hidraw0` to `hidraw2`; Pen/Touch was still applied and
verified automatically.

## Removal

Optionally select `touch` or `water` before removing the automatic setup, then run:

```sh
sudo systemctl stop 'fz-m1-touch-mode@*.service'
sudo rm /etc/udev/rules.d/99-fz-m1-touch-mode.rules
sudo rm /etc/systemd/system/fz-m1-touch-mode@.service
sudo rm /usr/local/sbin/fz-m1-touch-mode
sudo systemctl daemon-reload
sudo udevadm control --reload
```

The project does not alter firmware, Secure Boot, LUKS, TPM, the bootloader,
initramfs, disk partitions, or the kernel. See [NOTES.md](NOTES.md) for the confirmed
wire protocol, register map, safety reasoning, and validation details.

## Limitations

The passive stylus is expected to appear as a touch contact, not as a separate
libinput pen device. Pressure, hover, and side-button support are therefore not
expected. Only the Panasonic/Sharp device with VID/PID `04dd:9762` was tested.

The final physical distinction between finger and the original passive stylus still
requires a short hands-on input test by the device owner.

## Primary sources

- [Linux `hid-multitouch.c`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/hid/hid-multitouch.c)
- [Linux HID IDs](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/hid/hid-ids.h)
- [Microsoft touchscreen HID collections](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/touchscreen-required-hid-top-level-collections)
- [Panasonic FZ-M1 MK3 System Interface Manager](https://global-pc-support.connect.panasonic.com/dldocs/77402)
- [Panasonic FZ-M1 MK3 HID Drivers](https://global-pc-support.connect.panasonic.com/dldocs/77379)
- [Panasonic FZ-M1 MK3 System Interface Device](https://global-pc-support.connect.panasonic.com/dldocs/77368)
- [Panasonic touch-mode support information](https://global-pc-support.connect.panasonic.com/dldocs/77277)

Community posts were not used as the evidentiary basis for proprietary HID writes.

## License

[MIT](LICENSE) – Copyright © 2026 Michael Hartlapp.
