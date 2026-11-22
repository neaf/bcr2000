# Buttons, encoders and faders

Every element has one **standard output** (`.easypar`), optionally a **custom output**
(`.tx`, see [05-custom-output.md](05-custom-output.md)), a Show value flag, a Default,
and a mapping from physical position to value.

## Common settings

| Setting | BCL | Values | Notes |
|---|---|---|---|
| Show value | `.showvalue` | `off`, `on` | The 4-character display flashes the new value when the element is used. Values of 10000 or more lose the leading 1. `.easypar` sets it to off |
| Default | `.default` | `off`, 0 to 16383 | Initial value. Any selector clears it. `.easypar` overwrites it with a value that depends on the type. Needs no relation to the value range. `off` leaves the element without a value, so snapshots skip it. The device never writes `.default off` |
| Physical mapping | `.minmax v1 v2` | 0 to 16383 each | Position to value. Overrides the values inside `.easypar`. Direction may be reversed (v1 greater than v2) |
| Local | `.local` | `off`, `on` | Accepted, no known effect |

`.minmax` roles by element:

- Button: Value 1 is the first state, Value 2 the second.
- Encoder: Value 1 at the counterclockwise limit, Value 2 at the clockwise limit.
- Fader: Value 1 at the bottom, Value 2 at the top.

Value 1 and Value 2 do not stop the value from being set by Default or by incoming
MIDI to any number.

## Standard output types

Which type is available depends on the element.

| Type | Button | Encoder | Fader | MIDI produced |
|---|---|---|---|---|
| `CC` | yes | yes | yes | Control Change (`Bc controller value`) |
| `NRPN` | yes | yes | yes | Control Change sequence selecting an NRPN and setting data |
| `NOTE` | yes | no | no | Note On (`9c note velocity`), release is Note On velocity 0 |
| `PC` | yes | yes | yes | Program Change, optionally preceded by bank select |
| `AT` | yes | yes | yes | Channel aftertouch (`Dc`) or note aftertouch (`Ac`) |
| `PB` | no | yes | yes | Pitch Bend |
| `GS/XG` | yes | yes | yes | Roland GS and Yamaha XG main controls as CC or NRPN |
| `MMC` | yes | no | no | MIDI Machine Control SysEx |

`c` is the channel minus 1. There is no Note Off type. Use Note On with velocity 0.

### CC

Button: `.easypar CC channel controller value1 value2 mode [increment]`
Encoder and fader: `.easypar CC channel controller value1 value2 mode`

| Argument | Range |
|---|---|
| channel | 1 to 16 |
| controller | 0 to 127 |
| value1, value2 | 0 to 16383 (value2 may be `off` on buttons) |
| button mode | `toggleoff`, `toggleon`, `increment` |
| increment | -127 to -1 or 1 to 127 (0 gives error 11) |
| encoder and fader mode | `absolute`, `relative-1`, `relative-2`, `relative-3`, `inc/dec`, `absolute/14`, `relative-1/14`, `relative-2/14`, `relative-3/14` |

Value 1 and 2 accept 14 bits even though a CC value is 7 bits. The device sends the
low 7 bits, and uses the full number in its own increment and value logic.

Side effects: Default becomes Value 2 on buttons (0 if `off`) and Value 1 on
encoders and faders. Show value off. Custom output cleared.

14-bit modes send MSB on the controller and LSB on controller plus 32, but only
for controllers 0 to 31. For 32 and up they behave like the matching 7-bit mode.
`inc/dec` is meant for NRPN. On CC it sends nothing, but still synchronizes values
with other elements on the same controller.

### NRPN

Same arguments as CC with an NRPN number 0 to 16383 instead of a controller.

Button output: `Bc 63 NRPN_MSB`, `Bc 62 NRPN_LSB`, `Bc 06 value_LSB`. Never data
entry LSB, so no 14-bit data. Encoder and fader output: the same selection, then
data by mode:

| Mode | Data |
|---|---|
| `absolute`, `relative-1`, `relative-2`, `relative-3` | `Bc 06 data` |
| `inc/dec` | One or more `Bc 60 01` for an increase, `Bc 61 01` for a decrease |
| `/14` modes | `Bc 06 dataMSB` then `Bc 26 dataLSB` |

For the 7-bit modes value 1 and 2 should stay within 0 to 127.

### NOTE (buttons)

`.easypar NOTE channel note velocity mode` with mode `toggleoff` or `toggleon`.

Press sends `9c note velocity`, release (toggleoff) or second press (toggleon)
sends `9c note 0`. Velocity 0 sent to the device becomes 1. Side effects: Default
0, Value 1 0, Value 2 velocity. In any custom output on the same button, the
value is the velocity on press, 0 on release (not the note number).

Input: an incoming Note On on the same channel and note updates the button. Its
LED lights if velocity is above the button velocity divided by 2. Note Off is
ignored.

### PC

Button: `.easypar PC channel bankMSB bankLSB program`
Encoder and fader: `.easypar PC channel bankMSB bankLSB`

Bank and program values are 0 to 127 or `off`. `off` skips that message.
Output order: `Bc 00 bankMSB` (unless off), `Bc 20 bankLSB` (unless off), `Cc program`.
Buttons use the fixed program. Encoders and faders send their value as the program.

Side effects on a button: mode `down`, Default, Value 1 and Value 2 become the
program (0 if off). Encoder and fader: Default 0, Value 1 0, Value 2 127.
Encoder resolution default is `24 24 24 24`.

### AT (aftertouch)

Button: `.easypar AT channel scope value1 value2 mode [increment]`
Encoder and fader: `.easypar AT channel scope value1 value2`

Scope is `all` for channel aftertouch (`Dc value`) or a note number 0 to 127 for
note aftertouch (`Ac note value`). Values are 0 to 127. Button modes and value
rules are the same as CC.

### PB (encoders and faders)

`.easypar PB channel range` with range 0 to 127.

Output `Ec 00 value`. The low byte is always 0, so there is no 14-bit pitch bend.
Default 64, Value 1 is 64 minus range div 2, Value 2 is 64 plus range div 2.
Range 0 or 1 gives an element that cannot move. Range 126 or 127 gives 1 to 127.

### GS/XG

Button: `.easypar GS/XG channel parameter value1 value2 mode`
Encoder and fader: `.easypar GS/XG channel parameter value1 value2`

Values 0 to 127. Button mode `toggleoff` or `toggleon` only. Parameters are
shortcuts for the GS and XG main controls. The NRPN type uses `Bc 62 MSB`,
`Bc 63 LSB`, `Bc 06 value`. Note that this NRPN order (62 first) differs from the
generic NRPN type (63 first).

| Parameter | Display | Controls | Sends |
|---|---|---|---|
| `cutoff` | CUTF | Filter cutoff | NRPN 01 20 |
| `resonance` | RESO | Filter resonance | NRPN 01 21 |
| `v-rate` | RATE | Vibrato rate | NRPN 01 08 |
| `v-depth` | DEPT | Vibrato depth | NRPN 01 09 |
| `v-delay` | DLY | Vibrato delay | NRPN 01 0A |
| `eg-attack` | ATC | EG attack time | NRPN 01 63 |
| `eg-decay` | DCY | EG decay time | NRPN 01 64 |
| `eg-release` | RELS | EG release time | NRPN 01 66 |
| `modulation` | MODU | Modulation | CC 01 |
| `p-time` | PORT | Portamento time | CC 05 |
| `volume` | VOL | Volume | CC 07 |
| `panorama` | PAN | Pan | CC 0A |
| `rev-send` | REVB | Reverb send | CC 5B |
| `crs-send` | CRS | Chorus send | CC 5D |
| `dly-send` | VARS | Delay or variation send | CC 5E |

### MMC (buttons)

`.easypar MMC device command location framerate`

| Argument | Values |
|---|---|
| device | `all` (byte `7F`) or 0 to 126 |
| command | `play` 02, `pause` 09, `stop` 01, `fwd` 04, `rew` 05, `locate`, `punch-in` 06, `punch-out` 07 |
| framerate | `noloc`, `24f` (bits 00), `25f` (20), `30df` (40), `30f` (60) |
| location | `HH:MM:SS.FF`, each part exactly 2 digits. Hours 0 to 23, minutes and seconds 0 to 59, frames 0 to rate minus 1. With `noloc` the field is required but ignored |

Output, when framerate is not `noloc`: `F0 7F device 06 44 06 01 (rate bits OR hours) M S F 00 F7`
(a locate with the position). When command is not `locate`: `F0 7F device 06 command F7`.
With `locate` and `noloc` nothing is sent. The device writes location as
`00:00:00.00` when `noloc`.

Side effects: mode `down`, Default 0, 24, 25, 30, 30 for `noloc`, `24f`, `25f`,
`30df`, `30f`, and Value 1 and Value 2 become 60 times hours plus minutes.

## Buttons

### Press and release modes

A button has one mode. Three statements set it: the selector (`down`), the mode
argument of `.easypar`, and `.mode`. The last one wins.

| `.easypar` mode | `.mode` | On push | On release | Notes |
|---|---|---|---|---|
| (PC, MMC) | `down` | message A | nothing | A is the on state |
| `toggleoff` | `updown` | message A | message B | B is the off state, only if Value 2 is not `off` |
| `toggleon` | `toggle` | A, then B on the next push | nothing | Value 2 `off` converts to 0 |
| `increment` | `incval n` | next step | nothing | Needs `increment n` |

Notes:

- With `toggleoff` and Value 2 `off`, release sends nothing. With Value 2 `0`,
  release sends 0. They are different.
- `.mode down` after a CC, NRPN, NOTE, AT or GS/XG `.easypar` leaves only message A.
  `.mode` after an `increment` easypar other than `incval` breaks the increment.
- When the device writes a button, it writes the original `.easypar` mode and never a
  `.mode` line for a button with standard output.
- `.mode incval` is written back as `down`. Increment is lost on read-back.
- `.mode` is meant for custom output. Combined with `.easypar` it overwrites the
  easypar mode.

### Increment mode

Used by CC, NRPN and AT. Start with Value = Default. On each push:

```
N = Value + Increment
if Increment > 0: Value = (N > Value1) ? Value2 : N
if Increment < 0: Value = (N < Value2) ? Value1 : N
```

- Value 1 must be greater than Value 2 for standard output, or the value sticks.
- Output wraps around.
- `.easypar` sets Default to Value 2, so a positive increment first sends
  Value 2 plus the increment, and a negative increment first sends Value 1.
  `CC 1 1 10 1 increment 2` sends 3, 5, 7, 9, 1, 3 and `increment -2` sends
  10, 8, 6, 4, 2, 10.
- For custom output (`.mode incval n` with `.minmax`) the roles swap: `.minmax`
  Value 1 is the minimum and Value 2 the maximum.
- A pair of buttons with opposite increments on the same controller works as up
  and down thanks to value synchronization. Different step sizes can be mixed.

### Button numbers with special roles

Buttons 53 to 56 become ordinary buttons when function keys are off or lock is on,
and 63 and 64 when lock is on. Foot switches are 61 and 62. See
[01-device.md](01-device.md).

## Encoders

Encoder statements in addition to the common ones:

### LED mode: `.mode`

| Mode | Ring shows |
|---|---|
| `off` | Nothing |
| `1dot` | One lit LED at the position |
| `1dot/off` | One LED, dark at value 0 |
| `12dot` | One LED over 12 positions |
| `12dot/off` | Same, dark at 0 |
| `bar` | Filled from the left |
| `bar/off` | Same, dark at 0 |
| `spread` | Grows from the centre |
| `pan` | Centre-based pan indicator |
| `qual` | Quality or Q style indicator |
| `cut` | Cut indicator |
| `damp` | Damp indicator |

The look of `spread`, `pan`, `qual`, `cut` and `damp` is inferred from their names **(unverified)**.
Encoders 33 to 56 have a single LED and use only `off`, `1dot` and `1dot/off`.
`.easypar` sets the LED mode to `off`, so send `.mode` after it.

### Resolution: `.resolution r1 [r2 [r3 [r4]]]`

The amount of value change per full turn at four rotation speeds, slowest first.

- Each value is 1 to 65535. Values of 32674 and above cause jumps and wrong
  endpoints in firmware 1.10, so 32673 is the practical maximum.
- Omitted values repeat the last one: `96 192` means `96 192 192 192`.
- Equal values give a constant response whatever the speed. Decreasing values are
  legal and make the knob feel wrong.
- Values may exceed the value range: `.resolution 1000` over 0 to 127 crosses the
  range in about an eighth of a turn.
- A selector sets `0 0 0 0` (dead knob). The device dumps that but rejects it on input.

Defaults set by `.easypar`:

| Type | Condition | R1 R2 R3 R4 |
|---|---|---|
| PC | any | 24 24 24 24 |
| CC, NRPN, AT, GS/XG | range 0 to 20 | 24 24 24 24 |
| | 21 to 200 | 96 96 96 96 |
| | 201 to 2000 | 96 192 384 768 |
| | 2001 to 16383 | 96 192 768 2304 |
| PB | range 0 to 21 | 24 24 24 24 |
| | 22 to 127 | 96 96 96 96 |

(Range means the absolute difference of Value 2 and Value 1.)

### Relative modes

Encoders and faders on CC or NRPN can send the amount of change instead of the
position. Change is positive for clockwise.

| Mode | Encoding | -2 | -1 | +1 | +2 |
|---|---|---|---|---|---|
| `relative-1` | Two's complement | 7E | 7F | 01 | 02 |
| `relative-2` | Binary offset 40 | 3E | 3F | 41 | 42 |
| `relative-3` | Sign bit 6 plus magnitude | 42 | 41 | 01 | 02 |

14-bit variants (`/14`) apply the same idea to MSB and LSB (relative-1/14:
-1 is `7F 7F`, +1 is `00 01`, relative-2/14: -1 is `3F 7F`, +1 is `40 01`,
relative-3/14: -1 is `40 01`, +1 is `00 01`). In relative modes the display
still respects the value range, but MIDI keeps being sent however far you turn.

## Faders (BCF2000 only)

Faders 1 to 8 are motorized. Fader 9 is the foot controller input.

| Statement | Values | Meaning |
|---|---|---|
| `.motor` | `off`, `on` | Fader moves itself when its value changes (preset selection, synchronization, incoming MIDI). Fader 9: stored, meaningless |
| `.override` | `move`, `pickup` | With motor off (always for fader 9): `move` jumps to the physical position at once. `pickup` waits until the fader reaches the last received value. Set Show value on with `pickup` |
| `.keyoverride` | `off`, button 1 to 64 | A button held to switch the motor off. Buttons 9 to 32 map to the same button in group 1. The device reports `off`, 1 to 8 or 33 to 64 |

Defaults: motor off, override `move`, key override off. One button can override
several faders.

## Value synchronization

Elements with standard output that point at the same MIDI target (same channel
plus controller, NRPN number, note, aftertouch scope and so on) share their
current value. Moving one updates all the others, whatever their type. Elements
with only custom output do not take part.

Uses: up and down buttons on one controller, coarse and fine encoders on one
parameter (different resolutions), several faders on one value.

A snapshot sends every element, so two elements on one target send twice. The
values can differ if their defaults differ and nothing has touched the target.
