import Foundation

/// Speex narrowband encoder using libspeex via dlopen/dlsym.
/// Encodes 8kHz mono Int16 PCM into Speex frames for TX audio over V7/TCP.
class SpeexEncoder {
    private var encoderState: OpaquePointer?
    private var bitsBuffer: UnsafeMutableRawPointer?
    private var bitsInited = false
    private var available = false
    private var libHandle: UnsafeMutableRawPointer?

    let frameSize = 160 // 20ms at 8kHz
    let sampleRate = 8000

    // Function pointers
    private var speex_lib_get_mode: (@convention(c) (Int32) -> OpaquePointer?)?
    private var speex_encoder_init: (@convention(c) (OpaquePointer) -> OpaquePointer?)?
    private var speex_encoder_destroy: (@convention(c) (OpaquePointer) -> Void)?
    private var speex_encode_int: (@convention(c) (OpaquePointer, UnsafePointer<Int16>, UnsafeMutableRawPointer) -> Int32)?
    private var speex_bits_init: (@convention(c) (UnsafeMutableRawPointer) -> Void)?
    private var speex_bits_destroy: (@convention(c) (UnsafeMutableRawPointer) -> Void)?
    private var speex_bits_reset: (@convention(c) (UnsafeMutableRawPointer) -> Void)?
    private var speex_bits_nbytes: (@convention(c) (UnsafeMutableRawPointer) -> Int32)?
    private var speex_bits_write: (@convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<CChar>, Int32) -> Int32)?
    private var speex_encoder_ctl: (@convention(c) (OpaquePointer, Int32, UnsafeMutableRawPointer) -> Int32)?

    init() {
        loadLibSpeex()
    }

    private func loadLibSpeex() {
        let execDir = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).deletingLastPathComponent()
        let paths = [
            execDir.appendingPathComponent("lib/libspeex.dylib").path,
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
            print("[SpeexEncoder] Could not load libspeex - TX audio disabled")
            return
        }

        typealias F_get_mode = @convention(c) (Int32) -> OpaquePointer?
        typealias F_enc_init = @convention(c) (OpaquePointer) -> OpaquePointer?
        typealias F_enc_destroy = @convention(c) (OpaquePointer) -> Void
        typealias F_encode_int = @convention(c) (OpaquePointer, UnsafePointer<Int16>, UnsafeMutableRawPointer) -> Int32
        typealias F_bits_init = @convention(c) (UnsafeMutableRawPointer) -> Void
        typealias F_bits_destroy = @convention(c) (UnsafeMutableRawPointer) -> Void
        typealias F_bits_reset = @convention(c) (UnsafeMutableRawPointer) -> Void
        typealias F_bits_nbytes = @convention(c) (UnsafeMutableRawPointer) -> Int32
        typealias F_bits_write = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<CChar>, Int32) -> Int32
        typealias F_enc_ctl = @convention(c) (OpaquePointer, Int32, UnsafeMutableRawPointer) -> Int32

        guard let s1 = dlsym(libHandle, "speex_lib_get_mode"),
              let s2 = dlsym(libHandle, "speex_encoder_init"),
              let s3 = dlsym(libHandle, "speex_encoder_destroy"),
              let s4 = dlsym(libHandle, "speex_encode_int"),
              let s5 = dlsym(libHandle, "speex_bits_init"),
              let s6 = dlsym(libHandle, "speex_bits_destroy"),
              let s7 = dlsym(libHandle, "speex_bits_reset"),
              let s8 = dlsym(libHandle, "speex_bits_nbytes"),
              let s9 = dlsym(libHandle, "speex_bits_write"),
              let s10 = dlsym(libHandle, "speex_encoder_ctl")
        else {
            print("[SpeexEncoder] Failed to resolve speex symbols")
            dlclose(libHandle)
            self.libHandle = nil
            return
        }

        speex_lib_get_mode = unsafeBitCast(s1, to: F_get_mode.self)
        speex_encoder_init = unsafeBitCast(s2, to: F_enc_init.self)
        speex_encoder_destroy = unsafeBitCast(s3, to: F_enc_destroy.self)
        speex_encode_int = unsafeBitCast(s4, to: F_encode_int.self)
        speex_bits_init = unsafeBitCast(s5, to: F_bits_init.self)
        speex_bits_destroy = unsafeBitCast(s6, to: F_bits_destroy.self)
        speex_bits_reset = unsafeBitCast(s7, to: F_bits_reset.self)
        speex_bits_nbytes = unsafeBitCast(s8, to: F_bits_nbytes.self)
        speex_bits_write = unsafeBitCast(s9, to: F_bits_write.self)
        speex_encoder_ctl = unsafeBitCast(s10, to: F_enc_ctl.self)

        bitsBuffer = UnsafeMutableRawPointer.allocate(byteCount: 128, alignment: 8)
        bitsBuffer!.initializeMemory(as: UInt8.self, repeating: 0, count: 128)
        speex_bits_init?(bitsBuffer!)
        bitsInited = true

        // Narrowband mode = 0
        guard let mode = speex_lib_get_mode?(0) else { return }
        encoderState = speex_encoder_init?(mode)

        // Quality 8 to match C# client
        var quality: Int32 = 8
        _ = speex_encoder_ctl?(encoderState!, 4, &quality) // SPEEX_SET_QUALITY = 4

        available = true
        print("[SpeexEncoder] Narrowband encoder initialized")
    }

    /// Encode a single frame of 160 Int16 samples (8kHz mono, 20ms).
    func encode(_ pcm: Data) -> Data? {
        guard available, let encoderState, let bitsBuffer else { return nil }

        let sampleCount = pcm.count / 2
        guard sampleCount == frameSize else { return nil }

        speex_bits_reset?(bitsBuffer)

        pcm.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: Int16.self).baseAddress!
            _ = speex_encode_int?(encoderState, ptr, bitsBuffer)
        }

        let nbytes = speex_bits_nbytes?(bitsBuffer) ?? 0
        guard nbytes > 0 else { return nil }

        var output = [CChar](repeating: 0, count: Int(nbytes))
        let written = speex_bits_write?(bitsBuffer, &output, nbytes) ?? 0
        guard written > 0 else { return nil }

        return Data(bytes: output, count: Int(written))
    }

    deinit {
        if let encoderState { speex_encoder_destroy?(encoderState) }
        if bitsInited, let bitsBuffer { speex_bits_destroy?(bitsBuffer) }
        bitsBuffer?.deallocate()
        if let libHandle { dlclose(libHandle) }
    }
}
