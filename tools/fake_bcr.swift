// Minimal virtual B-Control endpoint for observing host software.
// Creates one CoreMIDI destination (host -> fake device) and one source
// (fake device -> host), logs all SysEx frames as hex, and answers the
// wildcard identity request.
//
// Run: swift tools/fake_bcr.swift [seconds]

import CoreMIDI
import Foundation

let lifetime = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 120 : 120

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}

func log(_ s: String) {
    print(s)
    fflush(stdout)
}

var client = MIDIClientRef()
var source = MIDIEndpointRef()
var destination = MIDIEndpointRef()

let clientStatus = MIDIClientCreateWithBlock("FakeBCRClient" as CFString, &client) { notification in
    log("client notification: \(notification.pointee.messageID.rawValue)")
}
guard clientStatus == noErr else {
    log("MIDIClientCreate failed: \(clientStatus)")
    exit(1)
}

var packetList = MIDIPacketList()
var outgoing = MIDIPacketList()

func send(_ bytes: [UInt8]) {
    var list = MIDIPacketList()
    let packet = MIDIPacketListInit(&list)
    let _ = MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, bytes)
    let status = MIDIReceived(source, &list)
    log("TX \(hex(bytes)) status=\(status)")
}

let destStatus = MIDIDestinationCreateWithBlock(client, "Fake BCR Out" as CFString, &destination) { list, _ in
    let packet = list.pointee.packet
    let data = withUnsafeBytes(of: packet.data) { raw in
        Array(raw.prefix(Int(packet.length)))
    }
    guard !data.isEmpty else { return }
    log("RX \(hex(data))")
    // Wildcard identity request from a host.
    if data.count == 8, data[0] == 0xF0, data[1] == 0x00, data[2] == 0x20,
       data[3] == 0x32, data[4] == 0x7F, data[5] == 0x7F, data[6] == 0x01,
       data[7] == 0xF7 {
        // Try the short 8-byte identity reply first (device 1, BCR).
        send([0xF0, 0x00, 0x20, 0x32, 0x01, 0x15, 0x02, 0xF7])
    }
    // Device-specific identity request.
    if data.count == 8, data[0] == 0xF0, data[1] == 0x00, data[2] == 0x20,
       data[3] == 0x32, data[5] == 0x15, data[6] == 0x01, data[7] == 0xF7 {
        send([0xF0, 0x00, 0x20, 0x32, data[4], 0x15, 0x02, 0xF7])
    }
}

let srcStatus = MIDISourceCreate(client, "Fake BCR In" as CFString, &source)
guard destStatus == noErr, srcStatus == noErr else {
    log("endpoint creation failed: dest=\(destStatus) src=\(srcStatus)")
    exit(1)
}

log("ready: dest='Fake BCR Out' src='Fake BCR In' lifetime=\(lifetime)s")
RunLoop.main.run(until: Date().addingTimeInterval(lifetime))
log("done")
