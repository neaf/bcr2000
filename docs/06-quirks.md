# Quirks, limits and open questions

Behavior that differs from what the language suggests. Each item says what to do
about it in a manager. Firmware 1.10.

## Reading back loses or distorts data

| What happens | Consequence for a manager |
|---|---|
| A dump omits `.minmax` and `.tx` when `.easypar` exists | Never rely on a read-back to recover custom output next to a standard output. Keep your own copy |
| `.mode incval n` comes back as `down` | Increment value and custom-only increment buttons cannot be recovered from the device |
| A button with `.easypar` never gets a `.mode` line | The easypar mode is the truth |
| Checksum definitions come back without the method (`cks-1 2` returns as `2`) | Custom output with checksums cannot be recovered. Keep your own copy |
| `.default off` is never written, a missing `.default` means off | Reading cannot tell "no default" from "default left at the easypar value" except by the missing line |
| `.local` is never written | Unknown state |
| An encoder at `.resolution 0 0 0 0` is dumped but rejected on input (error 11) | Replace with valid values before sending |
| A LEARN `.tx` of exactly 125 bytes produces an over-long BCL line | Keep LEARN output to 124 bytes or less per statement |
| `40 7E` can wrap the message index past 16383 and the device cannot take such a chain back | Split writes into separate blocks. Do not echo a wrapped dump |

## Writing

| What happens | Consequence |
|---|---|
| `$store` over MIDI does not report a too-large preset (error 18 only on the panel) | Estimate preset size before sending (see below) |
| `.deviceid` takes effect on the next line | Send it last, or in its own chain, with the new address afterwards. Saved files omit it |
| Changing MIDI mode or device ID can reopen the USB MIDI ports | Warn the user. Software holding the ports can hang |
| Section selectors reset their section, so partial sections do not merge (except `$global`) | Send each preset and element in one piece |
| A bad element selector silently reselects the last element | Validate numbers before sending. An out-of-range `$encoder` line edits the previous encoder |
| `$store` does not copy values into defaults, the STORE button does | Do not expect a BCL store to freeze live values |
| The BCR accepts `$fader` dot statements without error after answering error 9 | Never send fader statements to a BCR |
| `.name` with apostrophes, missing quotes or control characters is altered | Strip apostrophes and non-printable characters |
| Dot statements right after `.easypar` can be overwritten by it | Order: `.easypar`, then `.showvalue`, `.default`, `.mode`, `.resolution`, `.minmax`, `.tx` |
| Other software changes settings: Reason sets send interval 2 and dead time 400 on both models and never restores them | Re-send global setup after using such programs |

## Behavior that surprises

- **14-bit anomaly.** CC and NRPN button values (and CC encoder values) accept 0 to
  16383 but only the low 7 bits are sent. The full number still drives the increment
  and display logic. Default is set to Value 2 unconditionally, even above 127.
  The panel refuses to raise such a value past 127.
- **NRPN is 7-bit only on buttons.** Data entry LSB is never sent. On encoders and
  faders the `/14` modes send both MSB and LSB.
- **Pitch bend is 7-bit.** The low byte is always 0.
- **Relative modes ignore the range.** The display stops at Value 1 and Value 2,
  but MIDI keeps being sent however far the knob turns.
- **`inc/dec` on CC.** Sends nothing but still synchronizes other elements on the
  same controller. Meant for NRPN.
- **Value synchronization** applies only to elements with standard output. A
  snapshot still sends each element, so shared targets are sent twice.
- **Dead time** applies to encoders and faders, not buttons.
- **Snapshot** skips elements whose value is off, including their custom output.
- **Function keys.** Switching function keys from off to on leaves the LEARN, EDIT
  and EXIT LEDs lit if they were lit (firmware bug).
- **Rotary encoder LEDs.** Encoders 33 to 56 take any mode name but only show three.
- **Value changes survive preset changes.** Snapshot after reselecting a preset
  sends the latest values, not the defaults.
- **`$rev` is loose.** Any text after the first revision character is accepted if it
  does not start with 0. `$preset` and `$end` accept stray arguments.
- **Unknown statements.** `.rangeon` and `.xref` exist but return error 13 in every
  section. `.local` is accepted and does nothing observable.
- **Panic reset** leaves the device untouched. It resets the receiver.

## Resolution bug

Resolution values of 32674 and above make the encoder jump: it can fail to reach
the maximum or go below it when turned at the matching speed. Use 32673 as the
limit.

## Limits

| Limit | Value |
|---|---|
| Memory presets | 32 |
| Preset name | 24 characters, codes 32 to 127 |
| Variable output data per preset | 4344 bytes BCR, 4956 bytes BCF |
| Custom output per element | 127 bytes buffer |
| LEARN output per preset | 127 bytes buffer |
| BCL line | about 512 characters |
| Chain length | 16384 lines (index 0 to 16383) |
| Value range | 0 to 16383 |
| Resolution | 1 to 32673 usable |
| Send interval | 2, 5, 10, 20, 50, 100 ms |
| Dead time | 0 to 1000 ms in steps of 10 |

### Estimating preset size

Raw memory has a fixed record per element and a 4344-byte area for custom output
and LEARN output. The simplest safe estimate is the buffer cost from
[05-custom-output.md](05-custom-output.md): add the cost of every element's `.tx`
statements plus the preset's LEARN output. Over 4344 is certainly too large. Whether
standard output also counts against the limit, as one source states, is
**(unverified)**.

## Open questions

- The visual behavior of the LED modes `spread`, `pan`, `qual`, `cut` and `damp`.
- The purpose of `.local`, `.rangeon`, `.xref`.
- The real meaning of the bytes `06 44` in the MMC locate message.
- The exact units of the rotation speed thresholds behind the four resolutions.
- Error codes 7, 16, 17, 19, 20, 21 and 23 have never been triggered.
- Whether any BCL item beyond those listed exists.
- How the 4344-byte area is consumed per item **(unverified)**.
