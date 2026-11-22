#!/usr/bin/env python3
"""Reference BCL/SysEx wire-format helper for Behringer B-Control devices.

This implements only the framing that host software uses. It is intentionally
small and dependency-free; it is not a full BCL semantic validator.

Examples:
  python3 tools/bcl_sysex.py encode preset.bcr preset.syx
  python3 tools/bcl_sysex.py decode preset.syx preset.bcr
  python3 tools/bcl_sysex.py inspect preset.syx
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

MANUFACTURER = bytes((0x00, 0x20, 0x32))
MODEL_BCF = 0x14
MODEL_BCR = 0x15
MODEL_ANY = 0x7F
DEVICE_ANY = 0x7F
MAX_INDEX = 16383


class BclError(ValueError):
    pass


@dataclass
class BclMessage:
    device: int
    model: int
    index: int
    text: str


@dataclass
class CommandMessage:
    device: int
    model: int
    command: int
    data: bytes


def _check_7bit(value: int, what: str) -> None:
    if not 0 <= value <= 0x7F:
        raise BclError(f"{what} out of 7-bit range: {value}")


def encode_command(device: int, model: int, command: int, data: bytes = b"") -> bytes:
    _check_7bit(device, "device")
    _check_7bit(model, "model")
    _check_7bit(command, "command")
    for i, b in enumerate(data):
        _check_7bit(b, f"data[{i}]")
    return bytes((0xF0,)) + MANUFACTURER + bytes((device, model, command)) + data + bytes((0xF7,))


def encode_bcl_message(device: int, model: int, index: int, text: str) -> bytes:
    if not 0 <= index <= MAX_INDEX:
        raise BclError(f"BCL index out of range: {index}")
    raw = text.encode("latin-1")
    for i, b in enumerate(raw):
        if not 0x20 <= b <= 0x7F:
            raise BclError(f"BCL text byte {i} out of range: 0x{b:02X}")
    data = bytes(((index >> 7) & 0x7F, index & 0x7F)) + raw
    return encode_command(device, model, 0x20, data)


def decode_frame(frame: bytes) -> CommandMessage:
    if len(frame) < 7:
        raise BclError("SysEx frame too short")
    if frame[0] != 0xF0 or frame[-1] != 0xF7:
        raise BclError("not an F0..F7 SysEx frame")
    if frame[1:4] != MANUFACTURER:
        raise BclError("not a Behringer (00 20 32) SysEx frame")
    device, model, command = frame[4], frame[5], frame[6]
    data = frame[7:-1]
    for i, b in enumerate(data):
        _check_7bit(b, f"payload[{i}]")
    return CommandMessage(device, model, command, data)


def decode_bcl_message(frame: bytes) -> BclMessage:
    msg = decode_frame(frame)
    if msg.command != 0x20:
        raise BclError(f"not a BCL message (command 0x{msg.command:02X})")
    if len(msg.data) < 2:
        raise BclError("BCL message lacks 14-bit index")
    index = (msg.data[0] << 7) | msg.data[1]
    try:
        text = msg.data[2:].decode("latin-1")
    except UnicodeDecodeError as exc:
        raise BclError("invalid BCL text") from exc
    return BclMessage(msg.device, msg.model, index, text)


def split_frames(data: bytes):
    """Yield complete F0..F7 frames, skipping non-SysEx bytes."""
    start = None
    for i, b in enumerate(data):
        if b == 0xF0:
            start = i
        elif b == 0xF7 and start is not None:
            yield data[start:i + 1]
            start = None


def encode_lines(lines, device=DEVICE_ANY, model=MODEL_BCR,
                 start_index=0, break_at_wrap=True, revision_line="$rev R1"):
    """Wrap BCL lines in SysEx messages, incrementing the 14-bit index.

    If the index would exceed 16383, restart at 0 and (by default) emit a
    fresh '$rev' line. Host software does the same, because the device cannot
    read back a wrapped chain.
    """
    out = []
    index = start_index
    for line in lines:
        line = line.rstrip("\r\n")
        if index > MAX_INDEX:
            index = 0
            if break_at_wrap:
                out.append(encode_bcl_message(device, model, index, revision_line))
                index += 1
        out.append(encode_bcl_message(device, model, index, line))
        index += 1
    return out


def _read_lines(path: Path):
    return path.read_text(encoding="latin-1").splitlines()


def cmd_encode(args):
    lines = _read_lines(Path(args.input))
    frames = encode_lines(lines, device=args.device, model=args.model,
                          start_index=args.start_index)
    Path(args.output).write_bytes(b"".join(frames))
    print(f"wrote {len(frames)} BCL messages / {sum(len(f) for f in frames)} bytes")


def cmd_decode(args):
    data = Path(args.input).read_bytes()
    lines = []
    expected = None
    for frame in split_frames(data):
        try:
            msg = decode_bcl_message(frame)
        except BclError as exc:
            print(f"skip: {exc}", file=sys.stderr)
            continue
        if expected is None or msg.index == 0:
            expected = msg.index + 1
        elif msg.index != expected:
            print(f"warning: index {msg.index}, expected {expected}", file=sys.stderr)
            expected = msg.index + 1
        else:
            expected += 1
        lines.append(msg.text)
    Path(args.output).write_text("\n".join(lines) + "\n", encoding="latin-1")
    print(f"wrote {len(lines)} BCL lines")


def cmd_inspect(args):
    data = Path(args.input).read_bytes()
    rows = []
    for frame in split_frames(data):
        try:
            msg = decode_bcl_message(frame)
        except BclError:
            try:
                cmd = decode_frame(frame)
            except BclError as exc:
                rows.append({"error": str(exc), "frame": frame.hex()})
                continue
            rows.append({"device": cmd.device, "model": cmd.model,
                         "command": f"0x{cmd.command:02X}",
                         "data": cmd.data.hex()})
            continue
        rows.append({"device": msg.device, "model": msg.model,
                     "index": msg.index, "text": msg.text})
    print(json.dumps(rows, indent=2))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)

    e = sub.add_parser("encode", help="bare BCL text -> .syx")
    e.add_argument("input")
    e.add_argument("output")
    e.add_argument("--device", type=lambda x: int(x, 0), default=DEVICE_ANY)
    e.add_argument("--model", type=lambda x: int(x, 0), default=MODEL_BCR)
    e.add_argument("--start-index", type=int, default=0)
    e.set_defaults(func=cmd_encode)

    d = sub.add_parser("decode", help=".syx -> bare BCL text")
    d.add_argument("input")
    d.add_argument("output")
    d.set_defaults(func=cmd_decode)

    i = sub.add_parser("inspect", help="dump frames as JSON")
    i.add_argument("input")
    i.set_defaults(func=cmd_inspect)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
