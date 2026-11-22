# BCL, the B-Control language

BCL is a line-oriented text language. The device accepts it inside SysEx
(see [02-transfer.md](02-transfer.md)); bank files hold the same text.

## Text rules

- Everything is case-sensitive. Only the hex digits `A` to `F` may be either case.
  The device always writes them in capitals.
- Extra spaces between words are allowed. The device indents dot statements by two
  spaces when it writes, and accepts them without indentation.
- Empty lines are allowed anywhere. The device never writes them.
- `;` starts a comment that runs to the end of the line. `#` and `//` are not
  comments. A `;` inside the quotes of `.name` is an ordinary character.
- The device never writes comments, so comments do not survive a read-back.
- Numbers are decimal or hex with a `$` prefix (`$7F`). A `+` sign is not allowed.
  Negative numbers use `-`.
- Lines are limited to roughly 512 characters.

## Blocks

A block starts with `$rev` and normally ends with `$end`.

| Statement | Meaning |
|---|---|
| `$rev R1` | Start a block for a BCR2000. `F1` for a BCF2000 |
| `$end` | End the block |

- The first letter must match the device: `R` for BCR, `F` for BCF, upper case.
  A wrong letter gives error 4 and ends the current section but not the block.
- The revision after the letter is optional, normally `1`. Anything is accepted as
  long as it does not start with `0` (error 5, which also ends the block).
- A chain sent to the device may hold several blocks, may leave out `$end`, and may
  hold an empty block. A chain from the device is one block.
- Statements outside a block give error 6.

## Sections

A section starts at a selector and runs until the next `$` line. There is no
section end statement.

| Selector | Section | Notes |
|---|---|---|
| `$global` | Global setup | Resets nothing. Partial sections are fine and several are allowed |
| `$preset` | Settings of the temporary preset | Resets name, snapshot, request, groups, function keys, lock and LEARN output. Does not clear elements |
| `$button N` | Button 1 to 64 | Resets that button |
| `$encoder N` | Encoder 1 to 56 (BCF 1 to 32) | Resets that encoder |
| `$fader N` | Fader 1 to 9 (BCF only) | BCR returns error 9 but still accepts the following dot statements without error |

Two commands are not sections:

| Command | Meaning |
|---|---|
| `$recall N` | Copy memory preset N (1 to 32) to the temporary preset. Same side effects as selecting a preset |
| `$store N` | Copy the temporary preset to memory preset N |

Consequences of the reset rules:

- The same selector twice in one chain does not merge. Only the dot statements
  after the last copy survive. For example `.request on` in a `$preset` section is
  undone by a later `$preset` section and so a later `.tx` LEARN output would not
  be sent at preset selection.
- Global sections do merge, so `.txinterval` and `.deadtime` can be sent in separate
  `$global` sections.
- Dot statements that belong to a section must follow their selector. A dot
  statement outside any section gives error 8. In the wrong section it gives error 13.

### Invalid element selectors

A selector with no number gives error 14, and a number out of range gives error 9.
Both reselect the most recently selected element of that kind, without resetting
it. The device remembers the selected button, encoder and fader across chains, so
dot statements after a bad selector edit a different element than intended. After
`.init` the selected elements are the highest ones (button 64, encoder 56 on a BCR).
The same happens at power on.

`$global` and `$preset` ignore stray text after them, with inconsistent error
behavior. Do not rely on it.

## Global statements

`.midimode`, `.startup`, `.footsw`, `.rxch`, `.deviceid`, `.txinterval`, `.deadtime`.
Values and meaning are in [01-device.md](01-device.md). The device writes them in
that order.

## Preset statements

| Statement | Values | Notes |
|---|---|---|
| `.name 'text'` | 0 to 24 characters, codes 32 to 127 | Always written as 24 characters. Longer gives error 12 |
| `.snapshot` | `off`, `on` | Send a snapshot when the preset is selected |
| `.request` | `off`, `on` | Send LEARN output when the preset is selected, before the snapshot |
| `.egroups` | 1 to 4 | Number of push encoder groups |
| `.fkeys` | `off`, `on` | Function keys |
| `.lock` | `off`, `on` | PRESET keys as buttons |
| `.tx b1 [b2 ...]` | bytes 0 to 255 | LEARN output, see [05-custom-output.md](05-custom-output.md) |
| `.init` | none | Clear every element of the temporary preset |

Written order: `.name`, `.snapshot`, `.request`, `.egroups`, `.fkeys`, `.lock`,
LEARN `.tx` lines, `.init`.

About names: control characters 1 to 31 become dots, and character 0 ends the
name. The apostrophe is the delimiter and misbehaves inside names: a missing
closing quote drops the last character, and an apostrophe inside often gives error 14
or an altered name that fails when read back. Avoid apostrophes. A preset
with `.init` omitted keeps whatever elements it had, but the device always writes
`.init` in dumps.

Defaults after `$preset`: name 24 spaces, snapshot off, request off, groups 4,
function keys on, lock off, LEARN output empty.

## Element statements

| Statement | Applies to | Purpose |
|---|---|---|
| `.easypar type ...` | all | Standard output, see [04-elements.md](04-elements.md) |
| `.showvalue` | all | Flash the value on the display |
| `.default n` or `off` | all | Initial value, 0 to 16383 or none |
| `.mode ...` | buttons | Press and release behavior, see [04-elements.md](04-elements.md) |
| `.mode ...` | encoders | LED ring mode |
| `.resolution r1 [r2 [r3 [r4]]]` | encoders | Value change per turn, four speed ranges |
| `.minmax v1 v2` | all | Physical position to value mapping |
| `.tx ...` | all | Custom output, see [05-custom-output.md](05-custom-output.md) |
| `.local` | buttons, encoders | Accepted, purpose unknown. Never written by the device |
| `.motor` | faders | Motor on or off (BCF) |
| `.override` | faders | `move` or `pickup` (BCF) |
| `.keyoverride` | faders | Button that disables the motor (BCF) |

Two more names, `.rangeon` and `.xref`, are known to the device but fail with error
13 in every section. Their arguments are unknown.

### What an element selector sets

| Setting | Button | Encoder | Fader |
|---|---|---|---|
| Standard output | none | none | none |
| Show value | off | off | off |
| Default | off | off | off |
| Value 1, Value 2 | 0, 0 | 0, 0 | 0, 0 |
| Mode | `down` | LED `off` | |
| Resolutions | | `0 0 0 0` | |
| Motor, override, key override | | | off, `move`, off |
| Custom output | none | none | none |

An encoder left at resolutions `0 0 0 0` does not respond to the knob, and the
device rejects `.resolution 0 0 0 0` with error 11 if you send back what it dumps.
Always send a valid `.resolution` for an encoder that has no `.easypar`.

### Order matters

`.easypar` has side effects (show value off, default, mode, value 1 and 2,
resolutions, custom output cleared). Put `.showvalue`, `.default`, `.mode`,
`.resolution` and `.minmax` after it. `.minmax` and `.tx` must come after
`.easypar` to coexist with it (see [05-custom-output.md](05-custom-output.md)).

### What the device writes for an element

Only elements with at least one non-default setting get a section. Within it:

| Statement | Written when |
|---|---|
| `.easypar` | standard output defined |
| `.showvalue` | always |
| `.mode` | buttons: only without standard output. Encoders: always |
| `.resolution` | encoders, always |
| `.motor`, `.override`, `.keyoverride` | faders, always |
| `.default` | default is not `off` |
| `.minmax` | no standard output |
| `.tx` | no standard output and custom output defined |

Order for buttons: `.easypar`, `.showvalue`, `.default`, `.mode`, `.minmax`, `.tx`.
Encoders: `.easypar`, `.showvalue`, `.mode`, `.resolution`, `.default`, `.minmax`,
`.tx`. Faders: `.easypar`, `.showvalue`, `.motor`, `.override`, `.keyoverride`,
`.default`, `.minmax`, `.tx`. Never `.local`.

Because `.minmax` and `.tx` are left out whenever `.easypar` exists, a preset that
uses both loses its custom output when read back. See [06-quirks.md](06-quirks.md).

## Error codes

| Code | Name | Meaning |
|---|---|---|
| 0 | noerr | Success |
| 1 | unknowntoken | Unknown word after `$` or `.` |
| 2 | datawithouttoken | Line does not start with `$`, `.` or `;` |
| 3 | argumentmissing | MIDI output argument expected, for example `.tx` alone or `cks-1` without its index |
| 4 | wrongdevice | `$rev` letter does not match the model. Ends the section |
| 5 | wrongrevision | `$rev` revision starts with 0. Ends the section and the block |
| 6 | missingrevision | Statement outside any block |
| 7 | internal | Never seen |
| 8 | modemissing | Dot statement outside any section |
| 9 | baditemindex | Element number out of range |
| 10 | notanumber | Number expected, for example `.default on` |
| 11 | valoutofrange | Number outside the allowed range, including `$store 33`, `.egroups 5` |
| 12 | invalidargument | Wrong word where a word was expected, bad `.name` |
| 13 | invalidcommand | Dot statement not allowed in this section |
| 14 | wrongnumberofargs | Too few or too many arguments |
| 15 | toomuchdata | `.tx` overflows the 127-byte buffer |
| 16 | alreadydefined | Never seen |
| 17 | presetmissing | Never seen |
| 18 | presettoocomplex | Preset too large to store. Only reported on the panel |
| 19 to 21 | wrongpreset, presettoonew, presetcheck | Never seen |
| 22 | sequence | Message index is not the expected one |
| 23 | wrongcontext | Never seen |

Check order the device uses: section present (8), then block (6), then section
type (13), then argument count (14, which wins over 4, 5, 10, 11 and 12).
