import Foundation

/// Opus encoder using system libopus via dynamic loading.
/// Encodes 48kHz mono Int16 PCM into Opus frames for TX audio.
///
/// On iOS, libopus must be bundled as a framework within the app.
class OpusEncoder {
    private var encoder: OpaquePointer?
    private let sampleRate: Int32 = 48000
    private let channels: Int32 = 1
    private let frameSize: Int32 = 960 // 20ms at 48kHz
    private let maxPacketSize = 4000
    private var libHandle: UnsafeMutableRawPointer?

    // Function pointers
    private var opus_encoder_create: (@convention(c) (Int32, Int32, Int32, UnsafeMutablePointer<Int32>) -> OpaquePointer?)?
    private var opus_encode: (@convention(c) (OpaquePointer, UnsafePointer<Int16>, Int32, UnsafeMutablePointer<UInt8>, Int32) -> Int32)?
    private var opus_encoder_destroy: (@convention(c) (OpaquePointer) -> Void)?

    init() {
        loadLibOpus()
    }

    private func loadLibOpus() {
        let bundlePath = Bundle.main.privateFrameworksPath.map { "\($0)/libopus.framework/libopus" }
        let paths = [
            bundlePath,
            Bundle.main.path(forResource: "libopus", ofType: "dylib"),
            "/opt/homebrew/lib/libopus.dylib",
            "/usr/local/lib/libopus.dylib",
        ].compactMap { $0 }

        for path in paths {
            if let handle = dlopen(path, RTLD_NOW) {
                libHandle = handle
                break
            }
        }

        guard let libHandle else {
            print("[OpusEncoder] Could not load libopus - TX audio disabled")
            return
        }

        typealias F_create = @convention(c) (Int32, Int32, Int32, UnsafeMutablePointer<Int32>) -> OpaquePointer?
        typealias F_encode = @convention(c) (OpaquePointer, UnsafePointer<Int16>, Int32, UnsafeMutablePointer<UInt8>, Int32) -> Int32
        typealias F_destroy = @convention(c) (OpaquePointer) -> Void

        guard let s1 = dlsym(libHandle, "opus_encoder_create"),
              let s2 = dlsym(libHandle, "opus_encode"),
              let s3 = dlsym(libHandle, "opus_encoder_destroy")
        else {
            print("[OpusEncoder] Failed to resolve opus symbols")
            dlclose(libHandle)
            self.libHandle = nil
            return
        }

        opus_encoder_create = unsafeBitCast(s1, to: F_create.self)
        opus_encode = unsafeBitCast(s2, to: F_encode.self)
        opus_encoder_destroy = unsafeBitCast(s3, to: F_destroy.self)

        // OPUS_APPLICATION_VOIP = 2048
        var error: Int32 = 0
        encoder = opus_encoder_create?(sampleRate, channels, 2048, &error)
        if error != 0 || encoder == nil {
            print("[OpusEncoder] Failed to create encoder, error: \(error)")
        } else {
            print("[OpusEncoder] Initialized successfully")
        }
    }

    func encode(_ pcm: Data) -> Data? {
        guard let encoder, let opus_encode else { return nil }

        let sampleCount = pcm.count / 2
        guard sampleCount == Int(frameSize) else { return nil }

        var output = [UInt8](repeating: 0, count: maxPacketSize)
        let result = pcm.withUnsafeBytes { raw -> Int32 in
            let ptr = raw.bindMemory(to: Int16.self).baseAddress!
            return opus_encode(encoder, ptr, frameSize, &output, Int32(maxPacketSize))
        }

        if result > 0 {
            return Data(output[0..<Int(result)])
        }
        return nil
    }

    deinit {
        if let encoder { opus_encoder_destroy?(encoder) }
        if let libHandle { dlclose(libHandle) }
    }
}
