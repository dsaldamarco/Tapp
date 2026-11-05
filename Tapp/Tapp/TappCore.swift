import Foundation
import Network

// ─────────────────────────────────────────────────────────────
// MARK: - Bonjour constants
// ─────────────────────────────────────────────────────────────

enum TappService {
    static let type       = "_tapp._tcp"
    static let domain     = "local."
    static let port: UInt16 = 57832
    static let serviceName  = "TappMac"
    static let multipeerServiceType = "tapp-remote"
}

// ─────────────────────────────────────────────────────────────
// MARK: - Event types (wire protocol)
// ─────────────────────────────────────────────────────────────

enum TappEventType: String, Codable {
    case keyDown, keyUp, mouseMove, leftClick, rightClick, ping, pong
    /// Two-finger scroll (uses mouseMovePayload as scroll deltas, in pixels)
    case scroll
    /// Unicode text typed with the iPhone system keyboard
    case text
    /// Left button press / release (used for drag & drop)
    case leftDown, leftUp
}

// ─────────────────────────────────────────────────────────────
// MARK: - Modifier flags
// ─────────────────────────────────────────────────────────────

struct KeyModifiers: OptionSet, Codable {
    let rawValue: Int
    static let command  = KeyModifiers(rawValue: 1 << 0)
    static let shift    = KeyModifiers(rawValue: 1 << 1)
    static let option   = KeyModifiers(rawValue: 1 << 2)
    static let control  = KeyModifiers(rawValue: 1 << 3)
    static let capsLock = KeyModifiers(rawValue: 1 << 4)
}

// ─────────────────────────────────────────────────────────────
// MARK: - Payloads
// ─────────────────────────────────────────────────────────────

struct KeyPayload: Codable {
    let keyCode: UInt16
    let modifiers: Int
    let character: String?

    init(keyCode: UInt16, modifiers: KeyModifiers, character: String? = nil) {
        self.keyCode    = keyCode
        self.modifiers  = modifiers.rawValue
        self.character  = character
    }
}

struct MouseMovePayload: Codable {
    let deltaX: Float
    let deltaY: Float
}

// ─────────────────────────────────────────────────────────────
// MARK: - TappPacket (the JSON frame sent over TCP)
// ─────────────────────────────────────────────────────────────

struct TappPacket: Codable {
    let type: TappEventType
    let keyPayload: KeyPayload?
    let mouseMovePayload: MouseMovePayload?
    let text: String?
    let timestamp: Double

    init(type: TappEventType,
         keyPayload: KeyPayload? = nil,
         mouseMovePayload: MouseMovePayload? = nil,
         text: String? = nil) {
        self.type = type
        self.keyPayload = keyPayload
        self.mouseMovePayload = mouseMovePayload
        self.text = text
        self.timestamp = Date().timeIntervalSince1970
    }

    static func keyDown(keyCode: UInt16, modifiers: KeyModifiers, character: String? = nil) -> TappPacket {
        TappPacket(type: .keyDown,
                   keyPayload: KeyPayload(keyCode: keyCode, modifiers: modifiers, character: character))
    }

    static func keyUp(keyCode: UInt16, modifiers: KeyModifiers, character: String? = nil) -> TappPacket {
        TappPacket(type: .keyUp,
                   keyPayload: KeyPayload(keyCode: keyCode, modifiers: modifiers, character: character))
    }

    static func mouseMove(deltaX: Float, deltaY: Float) -> TappPacket {
        TappPacket(type: .mouseMove, mouseMovePayload: MouseMovePayload(deltaX: deltaX, deltaY: deltaY))
    }

    static func scroll(deltaX: Float, deltaY: Float) -> TappPacket {
        TappPacket(type: .scroll, mouseMovePayload: MouseMovePayload(deltaX: deltaX, deltaY: deltaY))
    }

    static func text(_ string: String) -> TappPacket {
        TappPacket(type: .text, text: string)
    }

    static func leftClick() -> TappPacket  { TappPacket(type: .leftClick) }
    static func rightClick() -> TappPacket { TappPacket(type: .rightClick) }
    static func leftDown() -> TappPacket   { TappPacket(type: .leftDown) }
    static func leftUp() -> TappPacket     { TappPacket(type: .leftUp) }
    static func ping() -> TappPacket       { TappPacket(type: .ping) }
    static func pong() -> TappPacket       { TappPacket(type: .pong) }

    /// Packets that can be dropped without harm (sent unreliably for lowest latency)
    var isLossTolerant: Bool { type == .mouseMove || type == .scroll }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Wire serialisation (newline-delimited JSON)
// ─────────────────────────────────────────────────────────────

enum TappProtocol {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode(_ packet: TappPacket) throws -> Data {
        try encoder.encode(packet)
    }

    static func decode(_ data: Data) throws -> TappPacket {
        var trimmed = data
        if trimmed.last == 0x0A {
            trimmed.removeLast()
        }
        return try decoder.decode(TappPacket.self, from: trimmed)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FrameBuffer (TCP stream reassembly)
// ─────────────────────────────────────────────────────────────

final class FrameBuffer {
    private var buffer = Data()

    func feed(_ data: Data) -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        while let idx = buffer.firstIndex(of: 0x0A) {
            let frame = Data(buffer[buffer.startIndex..<idx])
            if !frame.isEmpty { frames.append(frame) }
            buffer.removeSubrange(buffer.startIndex...idx)
        }
        return frames
    }

    func reset() { buffer.removeAll() }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Mac Keycode Table
// ─────────────────────────────────────────────────────────────

enum KeyMapping {
    static func keyCode(for label: String) -> UInt16? {
        table[label.lowercased()]
    }

    // swiftlint:disable function_body_length
    private static let table: [String: UInt16] = {
        var m: [String: UInt16] = [:]
        // Letters
        let letters: [(String, UInt16)] = [
            ("a",0),("s",1),("d",2),("f",3),("h",4),("g",5),
            ("z",6),("x",7),("c",8),("v",9),("b",11),
            ("q",12),("w",13),("e",14),("r",15),("y",16),("t",17),
            ("o",31),("u",32),("i",34),("p",35),("l",37),("j",38),
            ("k",40),("n",45),("m",46)
        ]
        for (k,v) in letters { m[k] = v }
        // Numbers
        m["1"]=18; m["2"]=19; m["3"]=20; m["4"]=21; m["6"]=22
        m["5"]=23; m["="]=24; m["9"]=25; m["7"]=26; m["-"]=27
        m["8"]=28; m["0"]=29
        // Special keys
        m["space"]=49; m["⎵"]=49; m["return"]=36; m["⏎"]=36
        m["tab"]=48;   m["⇥"]=48; m["delete"]=51; m["⌫"]=51
        m["escape"]=53; m["esc"]=53
        m["⇧"]=56; m["shift"]=56; m["⌃"]=59; m["control"]=59
        m["⌥"]=58; m["option"]=58; m["⌘"]=55; m["command"]=55
        m["⇪"]=57; m["caps"]=57
        // Arrows
        m["←"]=123; m["→"]=124; m["↓"]=125; m["↑"]=126
        m["⌦"]=117; m["home"]=115; m["end"]=119; m["pgup"]=116; m["pgdn"]=121
        // Punctuation
        m["["]=33; m["]"]=30; m["'"]=39; m[";"]=41
        m["\\"]=42; m[","]=43; m["/"]=44; m["."]=47; m["`"]=50
        return m
    }()
}
