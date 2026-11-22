# bcr2000

Specification and bank editor for the Behringer BCR2000 control surface. Everything about
the device lives here: the language it speaks, its limits and bugs, a browser app that
edits and transfers banks, and the banks themselves. A bank is the global setup plus all
32 presets, stored as a plain `.bcr` text file in `banks/`, so git shows every change as a
readable diff.

| Folder | Contents |
|---|---|
| `docs/` | The BCR2000 reference: device, SysEx transfer, BCL, every output type, quirks, raw memory, verification plan |
| `spec/` | The same facts as JSON for code |
| `tools/` | BCL to SysEx converter, a virtual BCR for watching SysEx traffic |
| `examples/` | A small BCL file |
| `app/` | The editor, one HTML file |
| `banks/` | Your banks |

## Run

```sh
./run.sh
```

The script checks for Python 3.8 or newer (standard library only), picks a free port
starting at 8765, starts the server and opens a Chromium based browser (Chrome, Brave,
Edge, Chromium or Arc). Web MIDI with SysEx does not exist in Safari or Firefox. If the
server is already running it just opens the page. Ctrl+C stops it.

`NO_BROWSER=1 ./run.sh` starts the server only, `PORT=9000 ./run.sh` prefers another
port. Without the script: `python3 serve.py` and open http://127.0.0.1:8765.

The browser asks for MIDI and SysEx access the first time you press Detect on the
BCR2000 page. Opening `app/index.html` directly also works, but banks then stay in
memory only.

Edits save to `banks/<bank name>.bcr` about 0.4 seconds after you stop typing.
Commit the folder with git when you want a version.

## What the editor does

- Edits buttons and encoders in a table, one value or a whole selection at once
  (start and step per row for numbers). Covers every standard output type on the
  BCR2000: CC, NRPN, NOTE, PC with bank select, aftertouch, pitch bend, GS/XG, MMC.
- Detects a BCR2000, warns about MIDI loops, shows transfer progress. Receives its
  whole bank as a new file, sends a bank back, reads and writes single presets and the
  edit buffer, selects presets, requests snapshots.
- Keeps custom output and other statements it cannot edit, so a bank that uses them
  survives a round trip.
- Without a device, a simulated BCR2000 is listed on the BCR2000 page.

## Status

[docs/07-app-coverage.md](docs/07-app-coverage.md) lists what is done. Not done: custom
output editing (out of scope), BCF2000 (deferred), compare and search. The items still
to confirm on hardware are in [docs/09-verification.md](docs/09-verification.md).
