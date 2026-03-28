import Foundation

enum ControlByte {
    static let HEARTBEAT: UInt8 = 0x00
    static let PTT: UInt8 = 0x03
    static let PINGPONG: UInt8 = 0x05
    static let PTT_OFF: UInt8 = 0x06
    static let KEY_OFF: UInt8 = 0xFB
    static let KEY_ON: UInt8 = 0xFC
    static let USERIN: UInt8 = 0xFD
    static let USEROUT: UInt8 = 0xFE
    static let UTF8STRING: UInt8 = 0xFF
}

let HEARTBEAT_TIMEOUT_MS: Int = 15_000
let HEARTBEAT_INTERVAL_MS: Int = 4_000
let PING_INTERVAL_MS: Int = 1_000
let DEFAULT_CMD_PORT: Int = 4525
let DEFAULT_AUDIO_PORT: Int = 4524

let OPUS_SAMPLE_RATE: Int = 48000
let OPUS_CHANNELS: Int = 1
let OPUS_BITRATE: Int = 24000
let OPUS_FRAME_MS: Int = 20
let OPUS_FRAME_SIZE: Int = (OPUS_SAMPLE_RATE * OPUS_FRAME_MS) / 1000 // 960

enum PacketType {
    case audio
    case command
    case heartbeat
    case pingpong
    case pttOn
    case pttOff
    case keyOn
    case keyOff
    case userIn
    case userOut
}

func classifyPacket(_ data: Data) -> PacketType {
    if data.isEmpty { return .heartbeat }
    let firstByte = data[data.startIndex]

    if firstByte == ControlByte.UTF8STRING && data.count > 1 { return .command }
    if data.count == 1 {
        switch firstByte {
        case ControlByte.HEARTBEAT: return .heartbeat
        case ControlByte.PINGPONG: return .pingpong
        case ControlByte.PTT: return .pttOn
        case ControlByte.PTT_OFF: return .pttOff
        case ControlByte.KEY_ON: return .keyOn
        case ControlByte.KEY_OFF: return .keyOff
        case ControlByte.USERIN: return .userIn
        case ControlByte.USEROUT: return .userOut
        default: break
        }
    }
    return .audio
}
