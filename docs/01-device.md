# The device

## Controls (BCR2000)

| Control | Count | Numbers | Notes |
|---|---|---|---|
| Push encoders | 8 physical, 32 virtual | encoders 1 to 32, buttons 1 to 32 | Each knob is 4 virtual encoders and 4 virtual buttons, one per encoder group |
| Rotary encoders | 24 | encoders 33 to 56 | Three rows of 8: top 33 to 40, middle 41 to 48, bottom 49 to 56 |
| Buttons | 64 | 1 to 64 | See the table below |
| Faders | none | | `$fader` selectors return error 9 |
| Foot switches | 2 | buttons 61 and 62 | |
| Display | 4 characters | | Shows values briefly when Show value is on |
| Ports | MIDI in, MIDI out A, MIDI out B or thru, USB | | Routing set by MIDI mode |

Push encoder LED rings have 12 LEDs and support every LED mode. The 24 rotary
encoders have a single LED each, so only `off`, `1dot` and `1dot/off` act on them.
They accept the other mode names without error but show nothing different.

### Button numbers

| Buttons | Meaning | Active when |
|---|---|---|
| 1 to 8 | Push encoders, group 1 | always |
| 9 to 16 | Push encoders, group 2 | encoder groups is 2 or more |
| 17 to 24 | Push encoders, group 3 | encoder groups is 3 or more |
| 25 to 32 | Push encoders, group 4 | encoder groups is 4 |
| 33 to 40 | Keys, upper row | always |
| 41 to 48 | Keys, lower row | always |
| 49 to 52 | User keys (bottom right) | always |
| 53 to 56 | STORE, LEARN, EDIT, EXIT | function keys off, or lock on |
| 57 to 60 | ENCODER GROUPS keys | see encoder groups table |
| 61 | Foot switch 1 | always |
| 62 | Foot switch 2 | BCR only |
| 63 and 64 | PRESET `=` and `<` | lock on |

An inactive button does not react, but the device still stores and returns its
definition. Definitions for buttons that do not exist (button 62 on a BCF) are
also stored.

### Encoder groups

Encoder groups says how many push encoder groups exist. The four ENCODER GROUPS
keys select groups; keys not needed as selectors become ordinary buttons.

| Groups | Push encoders available | Top left | Top right | Bottom left | Bottom right |
|---|---|---|---|---|---|
| 1 | 1 to 8 | button 57 | button 58 | button 59 | button 60 |
| 2 | 1 to 16 | group 1 | group 2 | button 59 | button 60 |
| 3 | 1 to 24 | group 1 | group 2 | group 3 | button 60 |
| 4 | 1 to 32 | group 1 | group 2 | group 3 | group 4 |

### Function keys and lock

| Function keys | Lock | STORE, LEARN, EDIT, EXIT | PRESET `=` and `<` |
|---|---|---|---|
| on | off | work as functions | select presets |
| off | off | buttons 53 to 56 | select presets |
| any | on | buttons 53 to 56 | buttons 63 and 64 |

## Memory model

- **Temporary preset.** What the device runs now. All BCL element and preset
  statements edit it. Lost at power off unless stored.
- **32 memory presets.** Survive power off. Selecting one copies its settings, not
  its current values, to the temporary preset.
- **Global setup.** One set of settings for the whole device. Survives power off.
- **Current value (Value).** Each element has a live value per memory preset. It
  is not part of a stored preset and is lost at power off. It starts at the
  element's Default. Selecting another preset does not reset it, so the 32 presets
  behave like one large preset whose values you never lose by switching.
- **Default.** The stored initial value. A value of `off` means the element has
  no value, and a snapshot skips it.

How Value changes:

1. Power on: Value becomes Default.
2. A BCL statement changes Default of a temporary preset element: the matching
   Value in the active memory preset follows.
3. A preset is stored: the target preset takes over the Value settings of the old
   active preset. Storing by BCL `$store` does not copy Value into Default. Storing
   with the STORE button does.
4. The user moves the element: Value follows.
5. A MIDI message matching the element's **standard** output arrives: Value
   follows. Elements with only custom output ignore incoming MIDI.

Elements that share the same MIDI target (channel plus controller, NRPN number,
note and so on) keep one synchronized value, whatever their type. See
[04-elements.md](04-elements.md).

## Global setup settings

| Setting | BCL | Values | BCR default | BCF default | Panel |
|---|---|---|---|---|---|
| MIDI mode | `.midimode` | `U-1` to `U-4`, `S-1` to `S-4` | `U-3` | `U-3` | push 1 |
| Receive channel | `.rxch` | `off`, 1 to 16 | `off` | `off` | push 2 |
| Foot switch | `.footsw` | `norm`, `inv`, `auto` | `auto` | `auto` | push 3 |
| Startup preset | `.startup` | `last`, 1 to 32 | `last` | `last` | push 4 |
| Device ID | `.deviceid` | 1 to 16 | 1 | 1 | push 5 |
| Dead time | `.deadtime` | 0 to 1000 ms | 0 | 100 | push 7 |
| Send interval | `.txinterval` | 2, 5, 10, 20, 50, 100 ms | 2 | 20 | push 8 |

Panel column: push encoder used in Global Setup mode (EDIT plus STORE). Push 6 is
a SysEx dump function.

- **MIDI mode** rewires the MIDI, USB and thru signal paths. Changing it can close
  and reopen the USB MIDI ports, which disturbs running audio software. Close
  programs first.
- **Startup preset** `last` restores the preset that was active at power off.
- **Foot switch** `norm` means closed circuit when pressed, `inv` closed when
  released, `auto` detects each pedal at power on. Only `auto` handles one normal
  and one inverted pedal on the BCR.
- **Receive channel** is the channel on which a Program Change selects a preset.
  `off` disables it.
- **Device ID** is the address in every SysEx message. The device replies to the
  `.deviceid` message with the old ID and uses the new one immediately, even for
  the next line of the same chain. Messages may also use `7F` (any device).
- **Dead time** is how long an encoder or fader ignores incoming MIDI after being
  moved. It prevents feedback loops and motor fights. Buttons ignore it. Values
  are rounded down to a multiple of 10. 1001 is rejected before rounding.
- **Send interval** is the minimum time before an element sends again after being
  moved twice quickly. Multiple messages from one move go out together. It does
  not slow SysEx dumps. Only the six listed values are accepted.

## Startup functions

Hold buttons while pressing POWER.

| Hold | Function | Display |
|---|---|---|
| STORE and LEARN | Bootloader mode (firmware update) | `LOAd` |
| STORE and EXIT | Start with an empty temporary preset | `Init` |
| Button 33 (BCF only) | Standard B-Control mode | `bC` |

Initialize works only in standard B-Control mode and is equivalent to sending an
empty `$preset` with `.init`. It is useful to avoid unwanted LEARN output at
startup. A BCR is always in standard mode.

### Bootloader

All controls are dead. The device answers only Request Identity (reply text
`BCR2000 BOOTLOADER 1.0`, device ID `7F`) and Send Firmware. Power cycling returns
to normal. The device enters it by itself if its firmware is invalid, showing
`noOS`.

### BCF2000 only: emulation modes

Holding button 34, 35, 36 or 37 at power on selects Mackie Control (Cubase and
Nuendo), Logic Control, Mackie Control (Sonar) or Mackie Baby HUI mapping. In these
modes only Request Identity and Send Firmware are understood, and Global Setup is
reduced (no receive channel, startup preset or SysEx dump). Mackie identity
messages (manufacturer `00 00 66`) can tell the modes apart. A BCR has none of this.

## Front panel functions

| Function | How | Result |
|---|---|---|
| Store preset | STORE, pick number, STORE | Copies temporary preset to a memory preset and copies Value into Default. Error 18 (`Err`) if too complex, memory preset untouched |
| Copy encoder group | STORE, then a group key | Copies a group's definitions |
| LEARN | Hold LEARN, move element | Defines custom output from the first MIDI message received (answers `GOOd` or `bAd`). One message only, no special items |
| Edit element | EDIT, move element | Edits value, mapping and mode on the push encoders |
| Edit global setup | EDIT plus STORE | See the global table |
| Data request | EDIT plus LEARN | Sends the preset's LEARN output |
| Panic reset | EDIT plus EXIT | Sends all notes off, all sound off, damper off and modulation 0 on every channel, then pitch bend centre on every channel |
| Snapshot | EDIT plus `=` PRESET | Sends output of every element that has a value |
| Single preset dump | EDIT plus `<` PRESET | Sends the temporary preset as BCL |
| Temporary local off | Hold EXIT, move element | Element moves without sending |
| Select preset | `=` or `<` PRESET, optionally hold and turn any encoder | Selects previous or next, or any preset by turning |

Panic reset does not change the device or its presets. Elements that use the
controllers it resets are not reset, so they can mismatch the receiver.

## Preset selection

Four ways: the PRESET keys, Program Change `Cn (preset - 1)` on the receive
channel, SysEx command `22`, or `$recall N` in BCL. Selecting a preset:

1. Copies its settings (not its Values) to the temporary preset.
2. If Request is on, sends the preset's LEARN output.
3. If Snapshot is on, sends a snapshot. The values sent are the latest ones, not
   the defaults, because Values survive preset changes.

## BCF2000 differences

| | BCR2000 | BCF2000 |
|---|---|---|
| Encoders | 56 | 32 |
| Faders | 0 | 8 motorized plus foot controller input as fader 9 |
| Foot switches | 2 | 1 |
| Model byte | `15` | `14` |
| `$rev` | `R1` | `F1` |
| Definition limit | 4344 bytes | 4956 bytes |
| Defaults for send interval, dead time | 2, 0 | 20, 100 |
| Emulation modes | none | 5 |
