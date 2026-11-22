# Custom output and LEARN output

Custom output makes an element send any MIDI it can describe: System Exclusive
messages, several messages at once, 14-bit values split any way, relative changes in
a custom encoding, checksums, and repeats. It is the way to control synths whose
parameters do not fit a standard output.

LEARN output is the same syntax, attached to the preset instead of an element, and
fixed bytes only.

## Syntax

```
.tx item item item ...
```

An element can have several `.tx` statements. They are sent in order every time
the element moves, after any standard output. The statement is the same in a
`$button`, `$encoder` and `$fader` section. At least one item is required (error 3).

| Item kind | Written as | Example |
|---|---|---|
| Fixed byte | decimal 0 to 255 or `$00` to `$FF` | `$F0`, `176`, `$7D` |
| Data specifier | `val` and friends | `val`, `val7.13` |
| Change definition | `rel2s`, `reloffs n`, `relsign n` | `reloffs $40` |
| Checksum | `cks-1 i`, `cks-2 i`, `cks-3 i` | `cks-1 2` |
| Direction | `ifp`, `ifn` | `ifp` |
| Repeat | `ntimes` | `ntimes` |

The device writes bytes and offsets in hex (`$F0`, `$0040`) and checksum start
indexes in decimal.

## Data

Every send computes one 14-bit number called Data:

- By default Data is the element's current value (as mapped by `.minmax`).
- After a change definition, Data is instead the amount of change since the last
  send, encoded by that definition. A change definition produces no output itself.
  The next data specifiers use the new meaning.

## Data specifiers

Each specifier outputs one MIDI byte that carries part of Data.

| Specifier | Bits | Byte sent |
|---|---|---|
| `val` | 0 to 6 | Data and `$007F` |
| `val0.6` | 0 to 6 | Same as `val`. The device writes it back as `val` |
| `val0` | 0 | Data and `$0001` |
| `val0.3` | 0 to 3 | Data and `$000F` |
| `val4.7` | 4 to 7 | (Data and `$00F0`) shifted right 4 |
| `val8.11` | 8 to 11 | (Data and `$0F00`) shifted right 8 |
| `val12.13` | 12 to 13 | (Data and `$3000`) shifted right 12 |
| `val7.13` | 7 to 13 | (Data and `$3F80`) shifted right 7 |
| `val1.7` | 1 to 7 | (Data and `$00FE`) shifted right 1 |

Bit 0 is the least significant. To send all 14 bits use one of three combinations,
in this order:

1. `val7.13` then `val0.6`: two 7-bit halves, MSB first. The common one.
2. `val12.13`, `val8.11`, `val4.7`, `val0.3`: four nibbles.
3. `val12.13`, `val8.11`, `val1.7`, `val0`: an unusual split that can carry 8 bits.

## Change definitions

| Item | Data equals | Like |
|---|---|---|
| `rel2s` | Change as two's complement | standard `relative-1` |
| `reloffs n` | n plus Change | generalized `relative-2` |
| `relsign n` | Change when positive, n minus Change when negative | generalized `relative-3` |

`n` is 0 to 16383 (decimal or hex). `rel2s` equals `reloffs 0`. With `relsign 0`
turning left and right produce identical output, which is useless.

Worked example (encoder 1, range 0 to 127):

```
.tx $F0 $7D val  rel2s val  reloffs $40 val  relsign $40 val  $F7
```

Turning one step clockwise and back sends:

```
F0 7D 01 01 41 01 F7       value 1, change +1 in each encoding
F0 7D 02 01 41 01 F7
F0 7D 03 01 41 01 F7
F0 7D 02 7F 3F 41 F7       change -1 in each encoding
F0 7D 01 7F 3F 41 F7
F0 7D 00 7F 3F 41 F7
```

## Checksums

`cks-1 i`, `cks-2 i` and `cks-3 i` each output one data byte. The checksum covers
the bytes from position `i` up to the byte just before it, counting from the first
byte after `.tx` as position 0 in that statement.

| Item | Method | Used by |
|---|---|---|
| `cks-1` | Negated sum, low 7 bits, so that the sum of covered bytes plus the checksum has bits 0 to 6 clear | Roland (RQ1, DT1), also reported for E-MU and Yamaha |
| `cks-2` | Sum of covered bytes, low 7 bits | Waldorf, Kurzweil |
| `cks-3` | XOR of all covered bytes | Fractal Audio, recommended by the MMA |

`i` is 0 to 127. The device does not complain about an index past the end.

Rules for reliable output:

- Start index counts from the beginning of the whole statement, not from the `$F0`.
  A second message in the same statement must use an index that points into itself.
- One SysEx message per `.tx` statement, always (see below).
- A checksum after `ntimes` is computed once, not per repeat.
- The device writes checksums back without the method name. See
  [06-quirks.md](06-quirks.md).

## Direction

| Item | Effect |
|---|---|
| `ifp` | Everything after it is output only when Change is positive |
| `ifn` | Everything after it is output only when Change is negative |

They may be repeated and mixed. `.tx ifp $C0 $01 ifn $C0 $02 ifp $C0 $03 ifn $C0 $04`
sends `C0 01 C0 03` upward and `C0 02 C0 04` downward. Direction is relative to the
element: use it with change definitions or just to send different bytes per direction.

## Repeat

`ntimes` repeats everything after it as many times as the size of the change. It
turns a relative move into a series of identical messages for devices that only
understand "step once".

- Only the last `ntimes` in a statement counts.
- It applies even after `ifp` or `ifn`: `ifp ntimes A ifn B` repeats both A and B.
- A statement can mix both: `... val rel2s $B0 $01 val ntimes $B0 $02 $00` sends the
  absolute value, the change, and then `B0 02 00` once per unit of change.

## Size limits

Each element's custom output (all of its `.tx` statements) and each preset's
LEARN output has a 127-byte buffer. Overflow gives error 15. Cost per item:

| Item | Bytes |
|---|---|
| `.tx` itself | 2 |
| Fixed byte (any but FE) | 1 |
| Fixed byte `$FE` (active sensing) | 2 |
| Data specifier, change definition, checksum, direction, repeat identifier | 2 |
| Offset argument of `reloffs` or `relsign` | 2 |
| Start index of a checksum | 1 |

Examples: `reloffs $0040` costs 4, `cks-1 6` costs 3. One statement with one `val`
has 123 bytes left for everything else. One statement can carry at most 125
plain bytes, two statements at most 123 together. A statement of exactly 125 bytes
produces a BCL line the device writes too long (its buffer is 512): it cannot
be read back cleanly. Keep to 124 or less.

### Preset limit

Each preset has 4344 bytes (BCR) of output memory, shared by custom output, LEARN output
and standard output. Measured on a BCR2000 (firmware 1.10), see
[09-verification.md](09-verification.md):

| Item | Bytes used |
|---|---|
| An element with custom output | the cost of all its `.tx` statements, plus 1 for the element |
| A second `.tx` on the same element | only its own cost (no extra overhead) |
| LEARN output | its statement cost, plus about 1 |
| Standard output, CC button (`toggleon`, `toggleoff` or `increment`) | 7 |
| Standard output, NOTE button | 7 |
| Standard output, NRPN button | 13 |
| Other output types | not measured yet |

Examples: 36 custom-output elements fit up to a total statement cost of 4308
(4344 minus 36), 50 elements up to 4294. Adding 64 CC buttons to a preset that held
4000 bytes of custom output made it too large.

If a preset is too large, a `$store` over MIDI is **silently ignored**: the device
replies with error 0 and the memory preset keeps its old content. The panel reports
error 18 instead. Check the size before sending, or read the preset back and compare.

## USB spurious bytes

If a SysEx message is followed by more output in the same `.tx` statement, the
device's USB port may send one to three extra bytes after it (the repeat of the end
of the SysEx message). The DIN MIDI outputs are not affected. The pattern depends on
the message length. A host driver may turn the extra bytes into a damaged channel
message.

The fix is one rule: **put every SysEx message at the end of its own `.tx`
statement**, in custom output and in LEARN output. The same applies to SysEx inside
an `ifp` or `ifn` clause when more bytes follow it.

## Combining standard and custom output

An element can have both. Put `.easypar` first, then `.minmax` and `.tx` (their
order does not matter).

- On every move the device sends the standard output first, then the custom output.
- Both use the value defined by `.minmax`. The Value 1 and Value 2 inside
  `.easypar` no longer matter, although a dump still shows them.
- Incoming MIDI only updates the value through the standard output. Custom output
  is deaf. Use it only for what standard output cannot do.
- A dump leaves out `.minmax` and `.tx` when `.easypar` exists, so the combined
  definition cannot be read back.
- `.minmax` on top of `.easypar` still changes the behavior and the MIDI, even
  without `.tx`: `.easypar CC 1 1 0 10 toggleon` with `.minmax 20 30` on a button
  sends 30, 20, 30, 20 and reads back as the unmodified `.easypar`.

Custom-only elements need more setup than standard ones. A custom-only button:

```
$button 33
  .mode toggle            ; press behavior: down, updown, toggle, incval n
  .minmax 0 127           ; value on the two states
  .default 0
  .showvalue on
  .tx $B0 20 val
```

A custom-only encoder needs a LED mode, a resolution and a range:

```
$encoder 5
  .mode 1dot
  .resolution 96 96 96 96
  .minmax 0 127
  .default 0
  .showvalue on
  .tx $B0 21 val
```

## Worked examples

Examples marked untested were composed from the rules above and not run on a device.

14-bit controller as MSB and LSB (modulation, channel 1):

```
.tx $B0 1 val7.13
.tx $B0 33 val0.6
```

Roland style parameter message with checksum (untested; each message in its own statement):

```
.tx $F0 $41 $10 $42 $12 $40 $01 $10 val cks-1 5 $F7
```

Relative encoder as step events (untested; up sends CC 10, down sends CC 11, repeated by amount):

```
.tx ifp ntimes $B0 10 127
.tx ifn ntimes $B0 11 127
```

(Direction applies to everything after it in the statement, so the two
directions can sit in one statement or two.)

## LEARN output

Preset-level `.tx` statements:

- Only fixed bytes. No special identifiers.
- Sent when the preset is selected and Request is on (before the snapshot), and when
  the user presses EDIT plus LEARN.
- The same 127-byte buffer rules apply: 125 bytes in one statement, 123 when split
  over two.
- You cannot clear one statement. Remove all LEARN output by sending a `$preset`
  section without any.
- One `.tx` per SysEx message, as above.
- The device writes LEARN output in hex.

## The panel LEARN function

Holding LEARN and moving an element lets the device capture one incoming MIDI
message as that element's custom output. It stores only the first message. It
cannot build multi-message output or use special items. The device answers `GOOd`
or `bAd` on the display. Anything richer needs a BCL chain.
