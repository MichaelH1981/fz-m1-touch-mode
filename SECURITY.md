# Safety and responsible testing

This tool is intentionally restricted to the Sharp controller with USB VID/PID
`04dd:9762` and to the exact mode values and register addresses recovered from the
Panasonic FZ-M1 MK3 software.

Do not adapt it to another controller by guessing commands, addresses, or values.
Vendor-defined HID writes may leave hardware in an unusable state. New writes should
be backed by an authoritative implementation or specification, first tested with a
read-only operation where possible, and followed by exact readback verification.

This project does not update controller firmware. Reports suggesting firmware
flashing, arbitrary register scanning, or guessed commands will not be accepted as
safe test procedures.
