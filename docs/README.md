# BCR2000 reference

What the Behringer BCR2000 can do and how to make it do it, in one place. The BCF2000 shares the language and most
behavior, so its differences are noted where they matter.

| File | Contents |
|---|---|
| [01-device.md](01-device.md) | Controls and numbering, memory model, startup functions, front panel functions |
| [02-transfer.md](02-transfer.md) | SysEx frame, commands, identity, reading and writing, files |
| [03-bcl.md](03-bcl.md) | The BCL language: syntax, blocks, sections, global and preset settings, error codes |
| [04-elements.md](04-elements.md) | Buttons, encoders and faders: every standard output type, modes, values, resolutions |
| [05-custom-output.md](05-custom-output.md) | `.tx` custom output and LEARN output: every special item, limits, worked examples |
| [06-quirks.md](06-quirks.md) | Firmware bugs, device behavior that surprises, limits, open questions |
| [07-app-coverage.md](07-app-coverage.md) | What this app supports today and what is missing |
| [08-raw-memory-and-firmware.md](08-raw-memory-and-firmware.md) | Raw preset image, global setup record, checksum, firmware transfer |
| [09-verification.md](09-verification.md) | Unverified items, experiments for real hardware, tools |

Machine-readable form: [../spec/bcr2000.json](../spec/bcr2000.json).
Tools: [../tools](../tools). Example: [../examples](../examples).

## Confidence

All statements refer to firmware 1.10. Statements marked **(unverified)** were not
confirmed on hardware. The experiments that would confirm them are in
[09-verification.md](09-verification.md).

## Conventions

- `$F0` is hexadecimal. Tables use plain hex digits where `$` would be noise.
- Channels are written 1 to 16 as in BCL. On the wire the channel nibble is 0 to 15.
- `off` is a legal value in several BCL arguments and is not the same as `0`.
- "Preset" means a 24-character-named group of element definitions. A "bank" in this
  app is the global setup plus all 32 presets.
