import Foundation

/// Opus codec using system libopus via C interop.
/// Falls back to silence if libopus is not available.
///
/// We use dlopen/dlsym to dynamically load libopus at runtime,
/// matching the koffi FFI approach from the Electron app.
class OpusDecoder {
    private var decoder: OpaquePointer?
    private let sampleRate: Int32 = 48000
    private let channels: Int32 = 1
    private let frameSize: Int32 = 960 // 20ms at 48kHz
    private let bytesPerFrame: Int = 960 * 2 // Int16 PCM
    private var libHandle: UnsafeMutableRawPointer?

    // Function pointers
    private var opus_decoder_create: (@convention(c) (Int32, Int32, UnsafeMutablePointer<Int32>) -> OpaquePointer?)?
    private var opus_decode: (@convention(c) (OpaquePointer, UnsafePointer<UInt8>?, Int32, UnsafeMutablePointer<Int16>, Int32, Int32) -> Int32)?
    private var opus_decoder_destroy: (@convention(c) (OpaquePointer) -> Void)?

    init() {
        loadLibOpus()
    }

    private func loadLibOpus() {
        let execDir = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).deletingLastPathComponent()
        let paths = [
            // Bundled inside the app (Contents/MacOS/lib/)
            execDir.appendingPathComponent("lib/libopus.dylib").path,
            // Homebrew
            "/opt/homebrew/lib/libopus.dylib",
            "/usr/local/lib/libopus.dylib",
        ]

        for path in paths {
            if let handle = dlopen(path, RTLD_NOW) {
                libHandle = handle
                break
            }
        }

        guard let libHandle else {
            print("[OpusDecoder] Could not load libopus - audio will be silent")
            return
        }

        typealias F_create = @convention(c) (Int32, Int32, UnsafeMutablePointer<Int32>) -> OpaquePointer?
        typealias F_decode = @convention(c) (OpaquePointer, UnsafePointer<UInt8>?, Int32, UnsafeMutablePointer<Int16>, Int32, Int32) -> Int32
        typealias F_destroy = @convention(c) (OpaquePointer) -> Void

        guard let s1 = dlsym(libHandle, "opus_decoder_create"),
              let s2 = dlsym(libHandle, "opus_decode"),
              let s3 = dlsym(libHandle, "opus_decoder_destroy")
        else {
            print("[OpusDecoder] Failed to resolve opus symbols")
            dlclose(libHandle)
            self.libHandle = nil
            return
        }

        opus_decoder_create = unsafeBitCast(s1, to: F_create.self)
        opus_decode = unsafeBitCast(s2, to: F_decode.self)
        opus_decoder_destroy = unsafeBitCast(s3, to: F_destroy.self)

        var error: Int32 = 0
        decoder = opus_decoder_create?(sampleRate, channels, &error)
        if error != 0 || decoder == nil {
            print("[OpusDecoder] Failed to create decoder, error: \(error)")
        } else {
            print("[OpusDecoder] Initialized successfully")
        }
    }

    func decode(_ packet: Data) -> Data? {
        guard let decoder, let opus_decode else {
            return Data(count: bytesPerFrame) // silence
        }

        var output = [Int16](repeating: 0, count: Int(frameSize))
        let result = packet.withUnsafeBytes { raw -> Int32 in
            let ptr = raw.bindMemory(to: UInt8.self).baseAddress!
            return opus_decode(decoder, ptr, Int32(packet.count), &output, frameSize, 0)
        }

        if result > 0 {
            return Data(bytes: output, count: Int(result) * 2)
        }
        return nil
    }

    deinit {
        if let decoder { opus_decoder_destroy?(decoder) }
        if let libHandle { dlclose(libHandle) }
    }
}
