# Talking to the device

All configuration travels as BCL text lines, each inside its own Behringer SysEx
message. There is no session, encryption or login. Identity, per-line replies and a
few request commands are all there is.

## SysEx frame

```
F0  00 20 32  <device>  <model>  <command>  <data...>  F7
```

| Part | Value |
|---|---|
| Manufacturer | `00 20 32` (Behringer) |
| Device | Device ID minus 1 (`00` to `0F`), or `7F` for any device |
| Model | `14` BCF2000, `15` BCR2000, `7F` any model |
| Data | 7-bit bytes only |

A device always answers with its own device ID and model, never `7F`. It ignores
messages for other device IDs.

## Commands

| Cmd | From | Meaning | Data |
|---|---|---|---|
| `01` | host | Request identity | none |
| `02` | device | Identity | optional text such as `BCR2000 1.10` |
| `20` | both | BCL line | 14-bit index, text |
| `21` | device | BCL reply | index, error code |
| `21` | device | Preset name | `00`, preset index, 24 characters (see below) |
| `22` | host | Select preset | preset number minus 1, `00` to `1F` |
| `34` | host | Firmware block | 296 encoded bytes |
| `35` | device | Firmware reply | address, error |
| `40` | host | Request data | `00` to `1F` one preset, `7E` global plus all filled presets, `7F` temporary preset |
| `41` | host | Request global setup | none |
| `42` | host | Request preset name | `00` to `1F`, `7E` all 32, `7F` temporary |
| `43` | host | Request snapshot | none |
| `78` | both | Send text (BCF emulation modes only) | first character index, characters |

Commands `40` and `41` answer with a BCL chain. `43` answers with ordinary MIDI
output (the snapshot, not BCL). The two `21` messages differ by length: a reply is
11 bytes long, a name message is 34.

Preset name message: `F0 00 20 32 dev model 21 00 <index> <24 characters> F7`.
The index is the preset number minus 1, or `7F` for the temporary preset. Names
are exactly 24 characters, space padded, no quotes.

## Identity

```
host   ->  F0 00 20 32 7F 7F 01 F7
device ->  F0 00 20 32 <dev> <model> 02 [text] F7
```

- The text is optional, and some hosts ignore everything after the command byte.
  Accept both a bare header and a header with printable text. A BCR2000 with firmware
  1.10 sends the text `BCR2000 1.10` (12 characters, no terminator), for example
  `F0 00 20 32 00 15 02 42 43 52 32 30 30 30 20 31 2E 31 30 F7`.
- In bootloader mode the text is `BCR2000 BOOTLOADER 1.0` and the device byte is `7F`.
- A practical scan sends the wildcard request to each MIDI output in turn and listens
  on all inputs for about a second per output, shortening the wait when replies come
  fast. A reply identical to the request means a MIDI loopback and must be ignored.
- Another approach sends two requests, first model `14` then `15`.

## BCL lines

```
F0 00 20 32 <dev> <model> 20 <indexMSB> <indexLSB> <text bytes> F7
```

- `index = MSB * 128 + LSB`, 0 to 16383.
- Text bytes are `20` to `7F`. Control bytes are rejected.
- A chain starts at index 0 with `$rev` and ends with `$end`. Each line is one
  message, and the next index is one higher. Index 0 always starts a new chain on
  the device.
- The device buffers about 512 characters per line.

### Replies

```
F0 00 20 32 <dev> <model> 21 <indexMSB> <indexLSB> <error> F7
```

Every line gets a reply with the same index and an error code (0 means success).
The device cannot be told to skip replies, but a host may ignore them. Waiting for
each reply is the reliable way to pace a transfer and to learn which line failed.
Error codes are in [03-bcl.md](03-bcl.md).

Sequence rules on the device: index 0 resets the expected index to 1, any other
index must equal the expected one. A mismatch gives error 22. A `$rev` line sent
with a wrong index can produce error 6.

## Reading from the device

| What | Request | Answer |
|---|---|---|
| Temporary preset | `40 7F` | BCL chain `$rev`, `$preset`, elements, `$end` |
| One memory preset | `40 (n-1)` | Same, without a `$store` line |
| Global setup | `41` | `$rev`, `$global`, `$end` |
| Global setup and every filled preset | `40 7E` | One long chain with `$store n` lines |
| Names | `42 ...` | Name messages |
| Snapshot | `43` | MIDI output for each element that has a value |

- A preset dump contains only elements that differ from defaults, and the `$preset`
  section includes `.init` so the receiver starts from an empty preset.
- `40 7E` can exceed 16384 lines. The device wraps the index back to 0 after 16383,
  and cannot read back a chain that wrapped, because index 0 restarts a chain.
  A manager reading it must treat the wrap carefully, and a manager writing must
  start a fresh block with a new `$rev` before the index would overflow.
- Every one of the 32 presets appears in `40 7E`, filled or not. An empty preset is a
  short block: `$preset`, `.name` with 24 spaces, `.snapshot off`, `.request off`,
  `.egroups 4`, `.fkeys on`, `.lock off`, `.init`, then `$store n`.
- Measured over a DIN MIDI link (BCR2000, firmware 1.10): a dump arrives at about 36
  lines per second. A preset with 84 defined elements was 434 lines in 12.2 s, the
  whole bank was 722 lines in 20.3 s, the global setup took 0.6 s and the 32 names
  1.5 s. Writing with a reply wait per line ran at about 42 ms per line (693 lines in
  29 s).
- Send one request at a time and wait for `$end`.

## Writing to the device

Send the chain line by line, waiting for each reply. A safe pace without replies is
about 60 ms per line.

Shape of a full bank write (the common bank file format):

```
$rev R1
$global
  .midimode ...   .startup ...   .footsw ...   .rxch ...
  .txinterval ... .deadtime ...
$preset
  .name '...'     .snapshot ...  .request ...  .egroups ...
  .fkeys ...      .lock ...      (.tx ... LEARN output)
  .init
$encoder 1
  ...
$button 1
  ...
$store 1
$preset
  ...
$store 2
...
$end
```

- `.deviceid` is left out of writes, because changing the ID changes the address of
  every later message in the chain.
- `$store N` copies the temporary preset to memory preset N. Send the whole preset
  first.
- Each `$preset` section resets all preset settings. Elements are only cleared by
  `.init` or by their own selector.
- The final preset in a bank file has no `$store`: it is the temporary preset.
- Comments, indentation and name padding are all optional when sending.
- Other ways to select a preset: command `22`, Program Change on the receive
  channel, `$recall N` in a chain.
- A `$store` of a preset that is too large returns error 18 from the panel but
  not over MIDI. Check the size yourself (see [06-quirks.md](06-quirks.md)).

## Files

| Extension | Content |
|---|---|
| `.bcr`, `.bcf`, `.txt`, `.bc2` | Plain BCL text, one statement per line. CRLF is the convention |
| `.syx` | Concatenated command `20` messages. Device byte `7F` makes a file portable across device IDs. Model `15` for BCR. A new `$rev` is inserted when the index would wrap |

A complete bank file holds `$global`, all 32 presets with `$store`, and the temporary
preset. Some editors also store presentation data (author, element names, colors) as
`;~key=value` comments and `;name` after selectors. The device ignores and never
returns them. This app does not use them.

## Raw memory and firmware

The device's raw preset image (8192 bytes, with a 4344-byte output area on the BCR),
the global setup record, the checksum and the firmware message format are documented
in [08-raw-memory-and-firmware.md](08-raw-memory-and-firmware.md). None of it is used
for normal transfer, and firmware flashing is out of scope for this app.
