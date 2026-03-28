import Foundation

/// Speex narrowband decoder using libspeex via dlopen/dlsym.
/// Parameters match decompiled NbDecoder.cs:
/// - Sample rate: 8000 Hz, Frame size: 160 samples (20ms), Mode: Narrowband
class SpeexDecoder {
    private var decoderState: OpaquePointer?
    private var bitsBuffer: UnsafeMutableRawPointer?
    private var bitsInited = false
    private var available = false
    private var libHandle: UnsafeMutableRawPointer?

    private let frameSize = 160
    private let bytesPerFrame = 320 // 160 * 2 (Int16)

    // Function pointers
    private var speex_lib_get_mode: (@convention(c) (Int32) -> OpaquePointer?)?
    private var speex_decoder_init: (@convention(c) (OpaquePointer) -> OpaquePointer?)?
    private var speex_decoder_destroy: (@convention(c) (OpaquePointer) -> Void)?
    private var speex_decode_int: (@convention(c) (OpaquePointer, UnsafeMutableRawPointer, UnsafeMutablePointer<Int16>) -> Int32)?
    private var speex_bits_init: (@convention(c) (UnsafeMutableRawPointer) -> Void)?
    private var speex_bits_destroy: (@convention(c) (UnsafeMutableRawPointer) -> Void)?
    private var speex_bits_read_from: (@convention(c) (UnsafeMutableRawPointer, UnsafePointer<CChar>, Int32) -> Void)?
    private var speex_bits_remaining: (@convention(c) (UnsafeMutableRawPointer) -> Int32)?
    private var speex_decoder_ctl: (@convention(c) (OpaquePointer, Int32, UnsafeMutableRawPointer) -> Int32)?

    init() {
        loadLibSpeex()
    }

    private func loadLibSpeex() {
        let execDir = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).deletingLastPathComponent()
        let paths = [
            // Bundled inside the app (Contents/MacOS/lib/)
            execDir.appendingPathComponent("lib/libspeex.dylib").path,
            // Homebrew
            "/opt/homebrew/lib/libspeex.dylib",
            "/usr/local/lib/libspeex.dylib",
        ]

        for path in paths {
            if let handle = dlopen(path, RTLD_NOW) {
                libHandle = handle
                break
            }
        }

        guard let libHandle else {
            print("[SpeexDecoder] Could not load libspeex - Speex audio will be silent")
            return
        }

        typealias F_get_mode = @convention(c) (Int32) -> OpaquePointer?
        typealias F_dec_init = @convention(c) (OpaquePointer) -> OpaquePointer?
        typealias F_dec_destroy = @convention(c) (OpaquePointer) -> Void
        typealias F_decode_int = @convention(c) (OpaquePointer, UnsafeMutableRawPointer, UnsafeMutablePointer<Int16>) -> Int32
        typealias F_bits_init = @convention(c) (UnsafeMutableRawPointer) -> Void
        typealias F_bits_destroy = @convention(c) (UnsafeMutableRawPointer) -> Void
        typealias F_bits_read = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<CChar>, Int32) -> Void
        typealias F_bits_rem = @convention(c) (UnsafeMutableRawPointer) -> Int32
        typealias F_dec_ctl = @convention(c) (OpaquePointer, Int32, UnsafeMutableRawPointer) -> Int32

        guard let s1 = dlsym(libHandle, "speex_lib_get_mode"),
              let s2 = dlsym(libHandle, "speex_decoder_init"),
              let s3 = dlsym(libHandle, "speex_decoder_destroy"),
              let s4 = dlsym(libHandle, "speex_decode_int"),
              let s5 = dlsym(libHandle, "speex_bits_init"),
              let s6 = dlsym(libHandle, "speex_bits_destroy"),
              let s7 = dlsym(libHandle, "speex_bits_read_from"),
              let s8 = dlsym(libHandle, "speex_bits_remaining"),
              let s9 = dlsym(libHandle, "speex_decoder_ctl")
        else {
            print("[SpeexDecoder] Failed to resolve speex symbols")
            dlclose(libHandle)
            self.libHandle = nil
            return
        }

        speex_lib_get_mode = unsafeBitCast(s1, to: F_get_mode.self)
        speex_decoder_init = unsafeBitCast(s2, to: F_dec_init.self)
        speex_decoder_destroy = unsafeBitCast(s3, to: F_dec_destroy.self)
        speex_decode_int = unsafeBitCast(s4, to: F_decode_int.self)
        speex_bits_init = unsafeBitCast(s5, to: F_bits_init.self)
        speex_bits_destroy = unsafeBitCast(s6, to: F_bits_destroy.self)
        speex_bits_read_from = unsafeBitCast(s7, to: F_bits_read.self)
        speex_bits_remaining = unsafeBitCast(s8, to: F_bits_rem.self)
        speex_decoder_ctl = unsafeBitCast(s9, to: F_dec_ctl.self)

        // Allocate SpeexBits struct (128 bytes safe)
        bitsBuffer = UnsafeMutableRawPointer.allocate(byteCount: 128, alignment: 8)
        bitsBuffer!.initializeMemory(as: UInt8.self, repeating: 0, count: 128)
        speex_bits_init?(bitsBuffer!)
        bitsInited = true

        // Narrowband mode = 0
        guard let mode = speex_lib_get_mode?(0) else { return }
        decoderState = speex_decoder_init?(mode)

        // Enable perceptual enhancement
        var enh: Int32 = 1
        _ = speex_decoder_ctl?(decoderState!, 0, &enh)

        available = true
        print("[SpeexDecoder] Narrowband decoder initialized")
    }

    func decode(_ packet: Data) -> Data? {
        guard available, let decoderState, let bitsBuffer else {
            return Data(count: bytesPerFrame)
        }

        packet.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: CChar.self).baseAddress!
            speex_bits_read_from?(bitsBuffer, ptr, Int32(packet.count))
        }

        var frames: [Data] = []
        while (speex_bits_remaining?(bitsBuffer) ?? 0) > 10 {
            var output = [Int16](repeating: 0, count: frameSize)
            let result = speex_decode_int?(decoderState, bitsBuffer, &output) ?? -1
            if result == 0 {
                frames.append(Data(bytes: output, count: bytesPerFrame))
            } else {
                break
            }
        }

        if frames.isEmpty { return nil }
        if frames.count == 1 { return frames[0] }
        var merged = Data()
        for f in frames { merged.append(f) }
        return merged
    }

    deinit {
        if let decoderState { speex_decoder_destroy?(decoderState) }
        if bitsInited, let bitsBuffer { speex_bits_destroy?(bitsBuffer) }
        bitsBuffer?.deallocate()
        if let libHandle { dlclose(libHandle) }
    }
}
