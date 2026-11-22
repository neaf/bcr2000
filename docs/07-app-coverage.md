# What this app covers

Status of every device capability in the app. Update this file with each change.
"Done" means editable in the UI and written to the file and to the device.

## Scope decisions

- **Custom output is out of scope.** No `.tx` editor, no custom-only elements, no
  LEARN output editing, no `.minmax`, no templates. [05-custom-output.md](05-custom-output.md)
  stays as reference. The app only keeps such statements intact.
- **BCF2000 is deferred** until it is needed.

## Statements the app keeps but does not edit

Reading a bank (file, `.syx`, or device) keeps these statements and writes them back
unchanged, so receiving a bank that uses them and sending it back loses nothing:

- `.tx` custom output, `.minmax` and a button's `.mode` on any element
- Elements that have only custom output (shown as a grey "custom" chip, all other
  cells blank). Setting a type on one keeps its custom statements next to the new
  standard output. Clearing the row removes them.
- LEARN output (`.tx` in `$preset`), shown as a note on the General page
- `.local`, `.motor`, `.override`, `.keyoverride`

These are not edited and not checked. Comments and `;name` lines are dropped.

## Device and bank

| Capability | Status | Notes |
|---|---|---|
| Global setup: MIDI mode, startup, foot switch, receive channel, send interval, dead time | Done | |
| Global setup: device ID | Partial | Edited and stored, never written to files or device |
| 32 presets and global setup as one bank | Done | One `.bcr` file per bank |
| Preset name, snapshot, request, encoder groups, function keys, lock | Done | |
| LEARN output | Kept | Not editable |
| Detect devices | Done | Wildcard identity request on every MIDI output |
| Transfer progress | Done | Top bar on every page plus a bar and text on the BCR2000 page. Receiving shows lines and the preset number (n of 32). Sending shows line n of total |
| MIDI loop detection | Done | Flags any frame the app sent that returns unchanged, during Detect and every transfer. Warning on the BCR2000 page and a red chip in the header |
| Read global setup and all presets (`40 7E`) | Done | Becomes a new bank. Index wrap past 16383 is handled |
| Write the whole bank | Done | Each line waits for its reply. Splits into several blocks if one would exceed 16000 lines. Errors name the preset and element |
| Read or write one preset | Done | Per slot, with a replace confirmation |
| Read or write the edit buffer (temporary preset) | Done | |
| Select preset (`22`) | Done | |
| Request snapshot (`43`) | Done | Sends the command. The device answers with MIDI that the app does not show |
| Preset names (`42`) | Not needed | Names come with a read |
| `.syx` import | Done | Also drag and drop |
| Size check against the preset limit | Missing | Standard output counts too (CC button 7 bytes, NRPN button 13). An oversized `$store` is silently ignored by the device, so a bank send can lose presets without an error. Needs the per-type costs first |
| Warning: resolution above 32673 | Done | |
| BCF2000 | Deferred | Model `14`, `$rev F1`, 32 encoders, faders, definition limit 4956 |
| Firmware update, raw memory images | Out of scope | See [02-transfer.md](02-transfer.md) |

## Elements

| Capability | Status | Notes |
|---|---|---|
| Button types CC, NRPN, NOTE, PC, AT, GS/XG, MMC | Done | MMC fields reuse columns: Param is the device, Value 1 the frame rate, Value 2 the location, Mode the command |
| Encoder types CC, NRPN, PC, PB, AT, GS/XG | Done | |
| Button modes toggleoff, toggleon, increment with increment value | Done | |
| Value 2 `off` on buttons | Done | Written as `off`, matters for `toggleoff` |
| PC bank MSB and LSB, program `off` | Done | PC rows reuse Value 1 as Bank MSB, Value 2 as Bank LSB, Param as Program. Encoders have no program |
| `.default off` | Done | Typing `off` in Default. Empty Default means the type's own default |
| Show value, default | Done | Writes always include an explicit `.default`, so a file never depends on the device's implicit choice |
| Dump semantics | Done | A device dump without `.default` means off, and the app reads it that way |
| Value 1 and 2 over 127 on CC and NRPN (14-bit anomaly) | Partial | Accepted up to 16383, no note about the 7-bit send |
| Encoder LED modes, with the 3-mode limit for encoders 33 to 56 | Done | A mixed selection only offers modes every row supports |
| Encoder resolutions (four values, auto from range) | Done | |
| Relative and 14-bit encoder modes | Done | |
| `.minmax`, custom output, custom-only elements, `.local` | Kept | Out of scope |
| Faders: motor, override, key override | Deferred | BCF only |
| Bulk edit with start and step | Done | |
| Inactive element marking (encoder groups, function keys, lock) | Done | |
| Duplicate target warning (same type, channel, parameter) | Done | CC, NRPN, NOTE |

## Editor

| Capability | Status |
|---|---|
| Banks stored as files, autosave | Done |
| Undo and redo | Done, per session |
| Copy, paste and clear a preset inside the bank | Done |
| Import a `.bcr` or `.syx` file | Done |
| Compare two presets or banks | Missing |
| Search for a controller or note across all presets | Missing |
| Print an overlay for the panel | Missing |
| Element names and comments | Dropped on purpose: the device does not store them |

## What is left

1. Compare presets, search for a controller or note across the bank.
2. Show the snapshot MIDI the device sends back (needs a MIDI input log).
3. BCF2000 when needed: model switch, 32 encoders, faders, emulation mode awareness.
