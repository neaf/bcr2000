# Raw memory and firmware

Normal configuration uses BCL text over SysEx ([02-transfer.md](02-transfer.md)).
This file records the device's internal structures for diagnostics and for firmware
work. Field names are inferred, not official. Every table here is **(unverified)**
against a real memory dump until the experiments in [09-verification.md](09-verification.md)
are done. The machine-readable form is `memory_presets.raw_layout` in
[../spec/bcr2000.json](../spec/bcr2000.json).

## Preset image (8192 bytes)

A memory preset image is 8192 bytes (`0x2000`). The last two bytes are a 16-bit
checksum, the rest is the preset.

### BCR2000

| Range | Size | Contents |
|---|---|---|
| `0000` to `0025` | 38 | header |
| `0026` to `0805` | 2016 | 56 encoder records of 36 bytes |
| `0806` to `0F05` | 1792 | 64 button records of 28 bytes |
| `0F06` to `1FFD` | 4344 | output byte area |
| `1FFE` to `1FFF` | 2 | checksum |

### BCF2000

| Range | Size | Contents |
|---|---|---|
| `0000` to `0025` | 38 | header |
| `0026` to `04A5` | 1152 | 32 encoder records of 36 bytes |
| `04A6` to `0B65` | 1792 | 64 button records of 28 bytes |
| `0BA6` to `0CA1` | 252 | 9 fader records of 28 bytes |
| `0CA2` to `1FFD` | 4956 | output byte area |
| `1FFE` to `1FFF` | 2 | checksum |

The output byte areas are exactly as large as the limits behind BCL error 18
(4344 and 4956 bytes). That is the main evidence that the limit concerns variable
output data, which means custom output and LEARN output, and that standard output
does not count against it.

### Header (38 bytes)

| Offset | Size | Meaning |
|---|---|---|
| 0 | 2 | model tag `R1` (BCF presumably `F1`) |
| 2 | 1 | encoder groups minus 1 (0 to 3) |
| 3 | 1 | flags: bit 7 always set, bit 0 function keys on, bit 1 request, bit 2 snapshot, bit 3 lock, bits 4 to 6 unknown |
| 4 | 2 | start of the output area: `0000` or `0F06` (BCR) / `0CA2` (BCF) |
| 6 | 8 | unknown, zero in written images |
| 14 | 24 | preset name, space padded |

### Element record (25 bytes)

Encoder, button and fader records embed this at offset 1.

| Offset | Size | Meaning |
|---|---|---|
| 0 | 1 | flags: bit 4 default enabled, bit 5 show value, others unknown |
| 1 | 2 | custom output or `.minmax` value 1 |
| 3 | 2 | custom output or `.minmax` value 2 |
| 5 | 2 | default value |
| 7 | 2 | index into the output byte area |
| 9 | 2 | constant `000C` |
| 11 | 1 | channel A |
| 12 | 1 | standard output status (high nibble), variant (low nibble) |
| 13 | 2 | packed parameter |
| 15 | 1 | standard output type |
| 16 | 1 | constant 0 |
| 17 | 2 | channel B |
| 19 | 2 | parameter |
| 21 | 2 | standard output value 1 |
| 23 | 2 | standard output value 2 |

### Encoder record (36 bytes)

| Offset | Size | Contents |
|---|---|---|
| 0 | 1 | LED mode |
| 1 | 25 | element record |
| 26 | 1 | standard output status byte |
| 27 | 1 | zero |
| 28 | 8 | four 16-bit resolutions |

### Button record (28 bytes)

| Offset | Size | Contents |
|---|---|---|
| 0 | 1 | button mode |
| 1 | 25 | element record |
| 26 | 2 | one word (increment, velocity and similar) |

Fader records have the same shape as button records.

### Checksum

Computed over bytes 0 to 8189 (8190 bytes):

- A running 8-bit sum starts at `54`.
- A second accumulator starts at `5A`. For each byte:

  ```
  if (acc & 0x80) == 0:  acc = byte ^ ((acc << 1) + 1)
  else:                  acc = byte ^ (acc << 1)
  ```

- The result combines both accumulators. The byte order of the stored word is not
  pinned down.

## Global setup record

A global setup record is 24 bytes: ten configuration bytes (MIDI mode, startup preset,
foot switch, receive channel, device ID, send interval, dead time and others), then two
words, three bytes and an array of seven bytes. A segment is 4096 bytes: 170 records
of 24 bytes plus a 16-byte trailer. The meaning of most bytes is unknown.

## Firmware transfer

Firmware travels as command `34` and is acknowledged by command `35`
([02-transfer.md](02-transfer.md)).

### Image and messages

- An image is a non-zero multiple of 4096 bytes, at most `80000` (512 KiB), so up to
  128 segments.
- Each 4096-byte segment becomes 16 SysEx messages. Each message is 304 bytes, so a
  segment occupies `1300` (4864) bytes in a `.syx` file.
- A message: `F0 00 20 32 <device> <model> 34 <296 encoded bytes> F7`.
- The 296 bytes are a 7-bit encoding of a 256-byte block, XORed with a repeating
  4-byte key. The key table has 210 entries of 32 bits, derived from fixed ASCII
  strings and one 4-byte constant **(unverified)**.
- The 256-byte block starts with a 32-bit code size and a 32-bit checksum, then code.
- The checksum rotates a 32-bit accumulator and sums `rotated XOR word` over the code
  words. Compare it with the stored value before sending.

### Reply

After every 16th message the device answers:

```
F0 00 20 32 <device> <model> 35 <addrMSB> <addrLSB> <error> F7
```

`addr` is the block address divided by 256. Error 0 is fine. Error 1 is a wrong
revision, and the display shows `Err5`. Bootloader mode answers identity requests with
`BCR2000 BOOTLOADER 1.0` and device byte `7F`.

Flashing is outside the scope of the editor. Do not send firmware without a verified
image and a known recovery path (the bootloader is reached with STORE and LEARN held
at power on).
