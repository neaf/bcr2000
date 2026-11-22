# Machine-readable spec

`bcr2000.json` describes the BCR2000 and BCF2000 protocol and preset model for code
that needs the numbers: SysEx addressing, commands, BCL framing and error codes,
element numbering, global and preset settings, standard output schemas, custom output
items and buffer costs, raw memory layout, timing and quirks. The prose version is in
[../docs](../docs/README.md). Both are maintained by hand.

Top-level sections:

| Key | Contents |
|---|---|
| `meta` | name, version and confidence |
| `manufacturer`, `models`, `device_id` | SysEx addressing |
| `sysex.commands` | command byte table |
| `bcl` | framing, chain rules, sections, block commands, error codes |
| `counts`, `button_map`, `encoder_map` | element model |
| `global_setup` | global fields, values, defaults |
| `preset` | preset fields, defaults, dump order |
| `element_common` | shared element settings and defaults |
| `button`, `encoder`, `fader` | type-specific settings |
| `standard_output` | `.easypar` argument schemas per type |
| `custom_output` | `.tx` items and buffer accounting |
| `memory_presets` | BCL indexes, request commands, snapshot, raw layout |
| `files` | `.bcr`, `.bcf`, `.syx`, `.txt` behavior |
| `detection` | identity request and timing |
| `timing` | practical pacing and timeouts |
| `quirks` | device bugs a host must tolerate |

Values such as `"off|0..127"` are shorthand for the BCL alternatives. Fields marked
"guessed" in `memory_presets.raw_layout` are inferred and need validation against real
memory dumps before they count as fact.
