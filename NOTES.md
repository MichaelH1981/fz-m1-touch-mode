# Panasonic FZ-M1 MK3 touch-controller notes

## Safety boundary

No Panasonic binary has been executed. All findings below come from static analysis of
Panasonic's FZ-M1 MK3 System Interface Manager package and its bundled Sharp
`tpcapi.dll`. No firmware-update path is involved.

The controller uses the HID interrupt reports already declared in its descriptor:

- output report `0x06`, 64 bytes including the report ID;
- input report `0x05`, 64 bytes including the report ID;
- no checksum, CRC, sequence number, or authentication field.

## Outer request frame

Every request is zero-padded to 64 bytes:

```
offset  size  meaning
0       1     HID report ID = 0x06
1       1     0x00
2       1     payload length + 3
3       n     command payload
```

The Windows DLL rejects a payload longer than 63 bytes and writes exactly the HID
output-report length returned by `HidP_GetCaps` (64 bytes on this device).

## Response frame

The read thread accepts 64-byte report `0x05`. Static analysis showed message type
`0x05` in the DLL's normalized command-reply path. The first live, read-only request
showed that the controller's uninitialized Linux state returns the same command,
status, and data layout directly with raw message type `0x01`. The Linux tool accepts
both layouts and deliberately does not send the Windows-only stream-initialization
report. The following raw offsets are used:

```
offset  meaning
0       HID report ID = 0x05
1       raw message type = 0x01, or normalized type = 0x05
2       frame/count field (not needed to match a command reply)
3       command ID
4       status (0 means success)
7...    reply data for getter commands
```

A non-zero status does not signal the DLL's success event, so the public API call
eventually fails after its 5000 ms timeout. The Linux implementation treats a
matching non-zero status as an immediate error. Unrelated touch/input reports are
ignored while waiting for the matching command reply.

## Reconstructed commands

The bytes shown are the meaningful prefix; every output is padded to 64 bytes.

### Get mode (command 5, read-only operation)

```
06 00 07 08 05 00 00
```

Expected reply: report `05`, message type `01` or `05`, command `05`, status `00`; the raw
mode byte is at offset 7.

### Get system state (command 3, read-only operation)

```
06 00 07 08 03 00 00
```

Expected reply data at offsets 7..10: `state1`, `state2`, and a little-endian
16-bit state word.

### Set system state (command 2)

Payload construction recovered from `tpcapi.dll`:

```
06 00 0c 08 02 00 04 00 STATE1 BOOL_STATE2 WORD_LO WORD_HI
```

The second state byte is normalized to boolean (`1` only when its input is exactly
`1`). Reply command is `02`, status must be `00`.

### Set mode (command 4)

```
06 00 09 08 04 00 01 00 MODE
```

Reply command is `04`, status must be `00`. `tpcapi.dll` accepts mode values 0..10,
but only the exact values selected by Panasonic's FZ-M1 utility are considered known:

- `0x00`: Touch base mode (also used as the base for Glove)
- `0x01`: Pen/Touch
- `0x02`: Pen
- `0x0a`: Water

Glove is distinguished from Touch by additional threshold settings, not by a
different raw mode value.

### Register access (commands 0x54 and 0x55)

Panasonic's utility uses these commands for the per-profile thresholds. The address
and value fields are little-endian 32-bit integers.

Read one register:

```
06 00 0d 08 54 00 05 00 ADDR[4] 01
```

The reply contains the echoed address at offsets 7..10 and its value at 11..14.

Write one register:

```
06 00 10 08 55 00 08 00 ADDR[4] VALUE[4]
```

The reply command is `55` and status must be zero. Both commands, including a
same-value write before changing anything, were validated against the live device.

## Panasonic profiles

Static analysis of `TSCtrlPr.exe` and its `CModeParams` implementations recovered the
complete values below. The Linux tool applies them literally and reads every written
register back before reporting success.

| Profile | Raw mode | Finger threshold | Pen threshold | Water bound | Foot count |
|---|---:|---:|---:|---:|---:|
| Touch | `00` | 400 | - | - | - |
| Pen | `02` | 400 | 80 | - | - |
| Pen/Touch | `01` | 400 | 80 | - | - |
| Glove | `00` | 79 | - | - | - |
| Water | `0a` | 550 | - | 2000 | 8 |

Register mapping:

- finger threshold mirrors: `0x00201470`, `0x00201858`
- pen threshold mirrors: `0x00201478`, `0x00201860`
- water bound: `0x00201480`
- water foot count: `0x00201490`

Glove and Water were both applied to the live controller, verified by mode and
register readback, and the device was then returned to Pen/Touch. Changing away from
Water caused the firmware to restore inactive water parameters to its defaults
(400 and 5); this is controller behaviour rather than an extra Linux write.

## Exact Panasonic mode-change transaction

`TPC_Set_Mode(mode)` performs this reversible transaction:

1. Get system state (`08 03 00 00`).
2. Save all returned state bytes.
3. Set system state with `state1 = 0`, retaining `state2` and the 16-bit state word.
4. Set mode (`08 04 00 01 00 MODE`).
5. Restore the complete saved system state, including on the observed failure paths.

Each step waits at most 5000 ms for its matching successful response. The first live
request was only **Get mode**, so it did not change controller state. It returned
`05 01 40 05 00 01 00 0a ...`: command `05`, success status `00`, and raw mode
`0x0a` (Water) at offset 7. A following two-second read with no request produced no
report, confirming that this was the getter response rather than a periodic frame.

The controlled live mode change then completed successfully. With saved system state
`02 00 50 c3`, the controller acknowledged command 2 (temporary state), command 4
(mode `01`), command 2 (state restoration), and command 5 (verification), each with
status `00`. The final getter returned raw mode `0x01` (Pen/Touch).

## Failure handling in the Linux tool

The tool exclusively accepts the four mode values and six register addresses above.
It takes an exclusive lock on the matching hidraw node, discovers the controller by
VID/PID rather than node number, and ignores unrelated input reports. Before applying
a profile it saves the current mode and every register that profile will touch. If a
write or verification fails, it restores those values and the previous mode. Mode
changes reproduce Panasonic's suspend/change/restore transaction exactly.

## Boot validation

After a real reboot the controller enumerated as `/dev/hidraw2` rather than its
previous `/dev/hidraw0`. The exact-match udev rule populated
`SYSTEMD_WANTS=fz-m1-touch-mode@hidraw2.service`; that instance completed with result
`success`, and its journal recorded successful Pen/Touch readback. A subsequent
independent query confirmed raw mode `0x01`, finger thresholds 400/400, and pen
thresholds 80/80. This validates that persistence does not rely on a fixed hidraw
index.

A later independent boot provided a second persistence check: the same controller
enumerated as `/dev/hidraw4`, `fz-m1-touch-mode@hidraw4.service` completed
successfully, and a read-only query again returned Pen/Touch raw mode `0x01`.
