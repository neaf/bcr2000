# Verification plan

Statements marked **(unverified)** in this reference have not been confirmed on a real
BCR2000. Nothing here has a recorded hardware result yet. This file lists the
experiments that would settle them, and the tools that help.

## Tools

| Tool | Use |
|---|---|
| `tools/bcl_sysex.py` | Convert BCL text to SysEx files and back, inspect `.syx` frames |
| `tools/fake_bcr.swift` | A virtual CoreMIDI endpoint (macOS). Logs every SysEx frame as hex and answers the wildcard identity request |
| The app's simulated BCR2000 | An in-browser device with identity, reads, writes, stores and reply codes. Selectable on the BCR2000 page |
| The app's transfer log | Every transfer step with its time |

The simulator behaves as this reference says. It cannot prove that the device does.

## Experiments

Each item names what to do and what the answer decides.

1. **Identity reply.** Send `F0 00 20 32 7F 7F 01 F7` and record the reply. Is it only
   the 8-byte header, or does it carry text such as `BCR2000 1.10`? Decides whether a
   host should parse the firmware version.
2. **Snapshot output.** Send command `43` with a MIDI monitor attached. Record which
   elements are sent, in what order, and what happens to elements with Default off.
3. **Size limit.** Store presets with growing custom output through the panel and by
   `$store`. Find the exact byte count at which the panel reports error 18 and
   compare with 4344. Test whether adding many standard outputs changes the
   threshold. Decides whether standard output counts against the limit.
4. **Raw memory checksum.** If a raw dump can be obtained (see experiment 6), compare the
   last two bytes with the two accumulators in [08-raw-memory-and-firmware.md](08-raw-memory-and-firmware.md)
   to fix the byte order.
5. **LED modes.** Set each of `spread`, `pan`, `qual`, `cut` and `damp` on a push
   encoder and describe the ring at minimum, middle and maximum values.
6. **SysEx dump.** Global Setup push encoder 6 triggers a SysEx dump. Capture it. Is it
   BCL, a raw memory image or something else?
7. **MMC locate.** Capture the message for an MMC locate button and check the bytes
   `06 44` after the device byte.
8. **Wrapped chain.** Request `40 7E` on a device with all 32 presets large enough to
   exceed 16384 lines, if reachable. Record the index sequence and what the device does
   when the same chain is sent back.
9. **Spurious USB bytes.** Reproduce the extra bytes after a non-final SysEx in `.tx`
   over USB and over DIN, and record the exact patterns for several lengths.
10. **Unknown statements.** Probe `.rangeon`, `.xref` and `.local` with different
    arguments and sections. Record every reply code.
11. **Error codes.** Try to trigger error codes 7, 16, 17, 19, 20, 21 and 23. Any hit
    is new knowledge.
12. **Store over MIDI.** Send a `$store` that is too large and check what the preset
    looks like afterwards and whether any error appears.
13. **Resolution thresholds.** Turn an encoder at measured speeds and find the
    rotation speeds at which the four resolution ranges switch.
14. **Value rules.** For each easypar type, press or turn with a MIDI monitor and check
    the exact bytes against [04-elements.md](04-elements.md), especially NRPN order
    for the GS/XG type versus the plain NRPN type, 14-bit modes and the toggle `off`
    behavior.
15. **Firmware key table.** If firmware work ever becomes relevant, validate the key
    table and the 7-bit packing against a known firmware file before sending anything.

## Recording a finding

Add the result to the matching reference file and remove its **(unverified)** marker.
Add a line below with the date, firmware version, model and method. Keep raw captures
under `captures/` as plain text hex.

## Not covered

Mackie-style emulation modes of the BCF2000, the BCF fader motors, and firmware
versions other than 1.10.

## Findings

None recorded yet.
