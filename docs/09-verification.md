# Verification

What has been confirmed on a real BCR2000 and what is left. Raw captures are in
[../captures](../captures) as plain text hex. Statements elsewhere in the reference
marked **(unverified)** are not in the confirmed list below.

## Tools

| Tool | Use |
|---|---|
| `tools/midiprobe.swift` | macOS CoreMIDI command line tool. Sends SysEx, waits for a BCL chain to end, or sends BCL lines one by one and prints each reply code. Build with `swiftc -O -o /tmp/midiprobe tools/midiprobe.swift` |
| `tools/bcl_sysex.py` | Convert BCL text to SysEx files and back, inspect `.syx` frames |
| `tools/fake_bcr.swift` | A virtual CoreMIDI endpoint that logs every SysEx frame |
| The app's simulated BCR2000 | An in-browser device. It behaves as this reference says, which does not prove the device does |

## Confirmed

Device: BCR2000, firmware 1.10, device ID 1, MIDI mode `S-4`, through a USB MIDI
interface (DIN). Date 2026-11-22.

| Finding | Captures |
|---|---|
| Identity reply is `F0 00 20 32 00 15 02` plus the text `BCR2000 1.10`, no terminator | `01` |
| Global dump order: `.midimode`, `.startup`, `.footsw`, `.rxch`, `.deviceid`, `.txinterval`, `.deadtime`. It includes `.deviceid` | `03` |
| Preset name messages are 34 bytes. All 32 arrive in 1.5 s. Index `7F` is the edit buffer | `04`, `05` |
| `40 7E` returns global setup and all 32 presets, empty ones as an 8-line block ending in `$store n` | `07` |
| Dump speed is about 36 lines per second. 434 lines took 12.2 s, the full bank 722 lines 20.3 s. Writing with a reply wait per line runs at about 42 ms per line | `02`, `07`, `14` |
| Error codes 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14 match the documented table. `$fader` gives 9 and the following fader statements are accepted. `.local` is accepted in a button and rejected in `$global` (13). `.rangeon` and `.xref` give 13 everywhere, with or without arguments. `.init` after `$end` gives 8. `$store 33` and `$recall 33` give 11 | `08` |
| Snapshot (`43`) sends encoders first, then buttons, each in ascending order | `10`, `12` |
| Snapshot bytes for every output type, including 14-bit modes, NRPN, PC with banks, PB, AT, GS/XG and NOTE, match [04-elements.md](04-elements.md) | `10`, `12` |
| GS/XG parameters that use NRPN select it with `Bc 63 MSB` then `Bc 62 LSB`, the same as the NRPN type | `10` |
| Relative encoders send the encoding of zero change in a snapshot. NRPN `inc/dec` sends only the NRPN selection | `10`, `12` |
| Snapshot sends nothing for buttons with `toggleoff` and Value 2 `off`, for `increment` buttons, PC buttons and MMC buttons | `10`, `12` |
| Default `off` is stored (no `.default` in the dump) but a snapshot still sends 0 for such an element | `12`, `13` |
| A `/14` mode on a controller of 32 or higher is stored and dumped as the 7-bit mode | `12`, `13` |
| `toggleon` converts a Value 2 of `off` to 0. `toggleoff` keeps `off` | `13` |
| `.easypar` resolution defaults match the table (`96 96 96 96` for 0 to 127, `96 192 768 2304` for 0 to 16383) | `13` |
| The app's parser and writer are lossless: a real 722-line dump went through the app, was sent to the device and read back identical, all 693 sent lines answered with error 0 | `14`, `15` |
| Output memory is 4344 bytes per preset and is shared by custom output, LEARN output and standard output | `size-results-*` |
| A custom-output element costs the sum of its `.tx` statement costs plus 1. Extra `.tx` statements on the same element add no further overhead | `size-results-2`, `-3` |
| A CC button (`toggleon`, `toggleoff`, `increment`) costs 7 bytes, a NOTE button 7, an NRPN button 13 | `size-results-4`, `-5` |
| LEARN output with a statement cost of 102 fits and one of 108 does not, in a preset with 36 custom elements and 4200 bytes of statements, so its overhead is about 1 byte | `size-results-3` |
| A `$store` of a preset that is too large returns error 0 and leaves the slot unchanged | `size-results-1` |

## Left to verify

Needs only MIDI:

- Error codes 6, 15 and 22, and the never-seen codes 7, 16, 17, 19, 20, 21 and 23.
- Standard output size cost for the other types: PC and PC with banks, AT, GS/XG, MMC,
  and every encoder type.
- The exact LEARN output overhead.
- Why a snapshot skips the button kinds listed above, and what a button with
  `toggleoff` and Value 2 `off` does when pressed.
- Behavior of a chain longer than 16384 lines.
- What the Global Setup SysEx dump function (push encoder 6) sends.
- Value rules: does `$store` keep live values, and the effect of preset selection on values.
- Whether a `.deviceid` change takes effect on the very next line.

Needs a person at the device:

- The look of the LED modes `spread`, `pan`, `qual`, `cut` and `damp` on a push encoder.
- The bytes of an MMC locate button (`06 44` after the device byte).
- The rotation speeds at which the four resolution ranges switch.
- Send interval and dead time effects.
- The extra bytes after a non-final SysEx in `.tx` over USB (needs a USB MIDI mode).

Needs firmware work, out of scope for now:

- The firmware key table and 7-bit packing, and the raw memory checksum byte order.

## Recording a finding

Add the result to the matching reference file and remove its **(unverified)** marker.
Add a row above with the date, firmware version, model and method, and keep the raw
capture under `captures/`.

## Not covered

Mackie-style emulation modes of the BCF2000, the BCF fader motors, and firmware
versions other than 1.10.
