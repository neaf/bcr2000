// Send SysEx to a MIDI destination and capture everything that comes back, as hex.
// macOS CoreMIDI, no dependencies.
//
//   swiftc -O -o /tmp/midiprobe tools/midiprobe.swift
//   /tmp/midiprobe ports
//   /tmp/midiprobe identity [listenMs]
//   /tmp/midiprobe send <dest> "<hex bytes>" [listenMs]
//   /tmp/midiprobe listen [listenMs]
//   /tmp/midiprobe chain <dest> "<hex>" [idleMs] [maxMs]   wait for a BCL chain to end with $end
//   /tmp/midiprobe bcl <dest> <file> [replyMs]                send BCL lines one by one, print each reply code
//   /tmp/midiprobe names <dest> "<hex>" <count> [idleMs]     wait for preset name messages
//
// <dest> is a destination number from `ports` or part of its name. Replies are printed
// as `+<ms> <source name>: <hex>`. SysEx split over several packets is reassembled.

import CoreMIDI
import Foundation

func name(_ e: MIDIEndpointRef) -> String {
    var s: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(e, kMIDIPropertyDisplayName, &s)
    return (s?.takeRetainedValue() as String?) ?? "?"
}
func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }
func parseHex(_ s: String) -> [UInt8] {
    s.split(whereSeparator: { " ,\n\t".contains($0) }).compactMap { UInt8($0.replacingOccurrences(of: "0x", with: "").replacingOccurrences(of: "$", with: ""), radix: 16) }
}

var client = MIDIClientRef()
MIDIClientCreate("midiprobe" as CFString, nil, nil, &client)
var inPort = MIDIPortRef()
var outPort = MIDIPortRef()
let t0 = Date()
var partial: [Int: [UInt8]] = [:]
var sawEnd = false
var nameCount = 0
var frameCount = 0
var replies: [Int: UInt8] = [:]
var lastFrameAt = Date()
let lock = NSLock()

MIDIInputPortCreateWithBlock(client, "in" as CFString, &inPort) { list, src in
    let srcRef = src?.load(as: MIDIEndpointRef.self) ?? 0
    let id = Int(srcRef)
    var packet = list.pointee.packet
    for _ in 0..<list.pointee.numPackets {
        let bytes = withUnsafeBytes(of: &packet.data) { Array($0.prefix(Int(packet.length))) }
        lock.lock()
        var buf = partial[id] ?? []
        var other: [UInt8] = []
        for b in bytes {
            if b == 0xF0 { buf = [b] }
            else if !buf.isEmpty { buf.append(b); if b == 0xF7 {
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                print("+\(ms) \(name(srcRef)): \(hex(buf))"); fflush(stdout)
                frameCount += 1; lastFrameAt = Date()
                if buf.count > 10, buf[6] == 0x20, String(bytes: buf[9..<(buf.count - 1)], encoding: .ascii)?.trimmingCharacters(in: .whitespaces) == "$end" { sawEnd = true }
                if buf.count >= 12, buf[6] == 0x21, buf[7] == 0 { nameCount += 1 }
                if buf.count == 11, buf[6] == 0x21 { replies[(Int(buf[7]) << 7) | Int(buf[8])] = buf[9] }
                buf = []
            } }
            else { other.append(b) }
        }
        if !other.isEmpty {
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            print("+\(ms) \(name(srcRef)): \(hex(other))"); fflush(stdout)
            other = []
        }
        partial[id] = buf
        lock.unlock()
        packet = withUnsafePointer(to: &packet) { MIDIPacketNext($0).pointee }
    }
}
MIDIOutputPortCreate(client, "out" as CFString, &outPort)

let nSrc = MIDIGetNumberOfSources(), nDst = MIDIGetNumberOfDestinations()
for i in 0..<nSrc { MIDIPortConnectSource(inPort, MIDIGetSource(i), nil) }

func send(_ dst: MIDIEndpointRef, _ bytes: [UInt8]) {
    var buf = [UInt8](repeating: 0, count: 1024 + 64)
    buf.withUnsafeMutableBytes { raw in
        let list = raw.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
        let p = MIDIPacketListInit(list)
        _ = MIDIPacketListAdd(list, raw.count, p, 0, bytes.count, bytes)
        MIDISend(outPort, dst, list)
    }
}
func dest(_ key: String) -> [MIDIEndpointRef] {
    if let i = Int(key), i >= 0, i < nDst { return [MIDIGetDestination(i)] }
    return (0..<nDst).map { MIDIGetDestination($0) }.filter { name($0).localizedCaseInsensitiveContains(key) }
}
func wait(_ ms: Int) { RunLoop.current.run(until: Date().addingTimeInterval(Double(ms) / 1000)) }

let a = CommandLine.arguments
guard a.count >= 2 else { print("usage: midiprobe ports | identity [ms] | send <dest> \"<hex>\" [ms] | listen [ms]"); exit(1) }
switch a[1] {
case "ports":
    print("sources:")
    for i in 0..<nSrc { print("  \(i)  \(name(MIDIGetSource(i)))") }
    print("destinations:")
    for i in 0..<nDst { print("  \(i)  \(name(MIDIGetDestination(i)))") }
case "identity":
    let ms = a.count > 2 ? Int(a[2]) ?? 1500 : 1500
    for i in 0..<nDst {
        let d = MIDIGetDestination(i)
        print("--- identity request to destination \(i) \(name(d))")
        send(d, [0xF0, 0x00, 0x20, 0x32, 0x7F, 0x7F, 0x01, 0xF7])
        wait(ms)
    }
case "send":
    guard a.count >= 4 else { print("send <dest> \"<hex>\" [ms]"); exit(1) }
    let ds = dest(a[2])
    guard let d = ds.first else { print("no destination matches \(a[2])"); exit(1) }
    let ms = a.count > 4 ? Int(a[4]) ?? 1500 : 1500
    print("--- to \(name(d)): \(hex(parseHex(a[3])))")
    send(d, parseHex(a[3]))
    wait(ms)
case "chain", "names":
    guard a.count >= 4, let d = dest(a[2]).first else { print("\(a[1]) <dest> \"<hex>\" ..."); exit(1) }
    // drain anything still arriving from an earlier request
    wait(2500)
    frameCount = 0; sawEnd = false; nameCount = 0
    let want = a[1] == "names" ? (a.count > 4 ? Int(a[4]) ?? 1 : 1) : 0
    let idle = Double(a[1] == "names" ? (a.count > 5 ? Int(a[5]) ?? 3000 : 3000) : (a.count > 4 ? Int(a[4]) ?? 3000 : 3000)) / 1000
    let maxS = Double(a[1] == "chain" && a.count > 5 ? Int(a[5]) ?? 90000 : 90000) / 1000
    print("--- to \(name(d)): \(hex(parseHex(a[3])))")
    let start = Date(); lastFrameAt = Date()
    send(d, parseHex(a[3]))
    while Date().timeIntervalSince(start) < maxS {
        wait(50)
        if a[1] == "chain" && sawEnd { break }
        if a[1] == "names" && nameCount >= want { break }
        if Date().timeIntervalSince(lastFrameAt) > idle { break }
    }
    wait(300)
    print("--- done: \(frameCount) frames in \(Int(Date().timeIntervalSince(start) * 1000)) ms, end=\(sawEnd), names=\(nameCount)")
case "bcl":
    guard a.count >= 4, let d = dest(a[2]).first, let text = try? String(contentsOfFile: a[3], encoding: .utf8) else { print("bcl <dest> <file> [replyMs]"); exit(1) }
    let replyMs = a.count > 4 ? Int(a[4]) ?? 2000 : 2000
    wait(1500)
    replies = [:]
    let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    for (i, line) in lines.enumerated() {
        var bytes: [UInt8] = [0xF0, 0x00, 0x20, 0x32, 0x7F, 0x15, 0x20, UInt8(i >> 7), UInt8(i & 127)]
        bytes += line.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) }
        bytes.append(0xF7)
        send(d, bytes)
        let st = Date()
        while replies[i] == nil && Date().timeIntervalSince(st) * 1000 < Double(replyMs) { wait(10) }
        let r = replies[i].map { String($0) } ?? "none"
        print("\(i)\t\(line)\t=> error \(r)"); fflush(stdout)
    }
case "listen":
    wait(a.count > 2 ? Int(a[2]) ?? 5000 : 5000)
default:
    print("unknown command \(a[1])")
}
