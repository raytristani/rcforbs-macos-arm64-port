import Foundation
import AVFoundation

enum CodecType {
    case opus
    case speex
}

/// Audio bridge: decodes network audio for playback, captures mic audio for TX.
/// Uses separate AVAudioEngines for playback and mic to avoid disrupting RX during TX.
class AudioBridge {
    private var codecType: CodecType = .opus
    private var isActive = false
    private var rxPacketCount = 0

    // Audio engine for playback (never stopped during TX)
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    // Separate engine for mic capture (created/destroyed per TX session)
    private var micEngine: AVAudioEngine?
    private var txConverter: AVAudioConverter?
    private var savedVolume: Float = 1.0
    private let sampleRate: Double = 48000
    private let format: AVAudioFormat

    // Opus decoder/encoder
    private var opusDecoder: OpusDecoder?
    private var opusEncoder: OpusEncoder?
    // Speex decoder/encoder
    private var speexDecoder: SpeexDecoder?
    private var speexEncoder: SpeexEncoder?

    // TX state
    private var isTXActive = false
    private var txPcmBuffer = Data()
    /// Frame size in samples for the active TX codec
    private var txFrameSize: Int { codecType == .speex ? 160 : 960 }

    // RX batching
    private var pendingPcm: [Data] = []
    private var pendingBytes = 0
    private var batchTimer: DispatchSourceTimer?
    private let batchFrames = 4
    private let audioQueue = DispatchQueue(label: "com.rcforb.audio", qos: .userInteractive)

    /// Callback to send encoded audio to network
    var onEncodedAudio: ((Data) -> Void)?

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    func start(_ codecType: CodecType = .opus) {
        guard !isActive else { return }
        self.codecType = codecType
        isActive = true
        rxPacketCount = 0
        pendingPcm = []
        pendingBytes = 0

        if codecType == .opus {
            opusDecoder = OpusDecoder()
            opusEncoder = OpusEncoder()
            speexDecoder = nil
            speexEncoder = nil
        } else {
            speexDecoder = SpeexDecoder()
            speexEncoder = SpeexEncoder()
            opusDecoder = nil
            opusEncoder = nil
        }

        setupAudioEngine()
    }

    private func setupAudioEngine() {
        // iOS requires an active AVAudioSession for playback
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[AudioBridge] Failed to configure audio session: \(error)")
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            player.play()
            audioEngine = engine
            playerNode = player
        } catch {
            print("[AudioBridge] Failed to start audio engine: \(error)")
        }
    }

    func pushRXAudio(_ data: Data) {
        guard isActive else { return }

        var pcm: Data?
        if codecType == .opus {
            pcm = opusDecoder?.decode(data)
        } else {
            pcm = speexDecoder?.decode(data)
        }

        guard let pcm, !pcm.isEmpty else { return }
        rxPacketCount += 1

        let outputPcm: Data
        if codecType == .speex {
            outputPcm = upsample8to48(pcm)
        } else {
            outputPcm = pcm
        }

        audioQueue.async { [weak self] in
            self?.pendingPcm.append(outputPcm)
            self?.pendingBytes += outputPcm.count

            guard let self else { return }
            if self.pendingPcm.count >= self.batchFrames {
                self.flushToPlayer()
            } else if self.batchTimer == nil {
                let timer = DispatchSource.makeTimerSource(queue: self.audioQueue)
                timer.schedule(deadline: .now() + .milliseconds(40))
                timer.setEventHandler { [weak self] in self?.flushToPlayer() }
                timer.resume()
                self.batchTimer = timer
            }
        }
    }

    private func flushToPlayer() {
        batchTimer?.cancel()
        batchTimer = nil

        guard let player = playerNode, !pendingPcm.isEmpty else { return }

        var merged = Data()
        for chunk in pendingPcm { merged.append(chunk) }
        pendingPcm = []
        pendingBytes = 0

        let sampleCount = merged.count / 2
        guard sampleCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(sampleCount)

        let floatData = buffer.floatChannelData![0]
        merged.withUnsafeBytes { raw in
            let int16Ptr = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                floatData[i] = Float(int16Ptr[i]) / 32768.0
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    func startTX() {
        guard isActive, !isTXActive else { return }
        isTXActive = true
        txPcmBuffer = Data()

        // Check mic permission
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            }
            isTXActive = false
            return
        }

        // Create a separate engine for mic capture — never touch the playback engine
        let mic = AVAudioEngine()
        micEngine = mic

        let inputNode = mic.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let txTargetRate: Double = codecType == .speex ? 8000 : sampleRate
        let txTargetFormat = AVAudioFormat(standardFormatWithSampleRate: txTargetRate, channels: 1)!

        // Create converter once for the session to avoid per-callback overhead
        if inputFormat.sampleRate != txTargetRate || inputFormat.channelCount != 1 {
            txConverter = AVAudioConverter(from: inputFormat, to: txTargetFormat)
        } else {
            txConverter = nil
        }

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(480), format: inputFormat) { [weak self] buffer, _ in
            guard let self, self.isTXActive else { return }

            let convertedBuffer: AVAudioPCMBuffer?
            if let converter = self.txConverter {
                let ratio = txTargetRate / inputFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
                guard let output = AVAudioPCMBuffer(pcmFormat: txTargetFormat, frameCapacity: capacity) else { return }
                var isDone = false
                converter.convert(to: output, error: nil) { _, outStatus in
                    if isDone { outStatus.pointee = .noDataNow; return nil }
                    isDone = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                convertedBuffer = output
            } else {
                convertedBuffer = buffer
            }

            guard let convertedBuffer else { return }

            let frameLength = Int(convertedBuffer.frameLength)
            guard frameLength > 0, let floatData = convertedBuffer.floatChannelData?[0] else { return }

            var int16Data = Data(count: frameLength * 2)
            int16Data.withUnsafeMutableBytes { raw in
                let ptr = raw.bindMemory(to: Int16.self)
                for i in 0..<frameLength {
                    ptr[i] = Int16(clamping: Int(floatData[i] * 32767.0))
                }
            }

            self.audioQueue.async {
                self.txPcmBuffer.append(int16Data)
                self.drainTXBuffer()
            }
        }

        // Duck RX audio during TX to prevent feedback into the mic
        savedVolume = audioEngine?.mainMixerNode.outputVolume ?? 1.0
        audioEngine?.mainMixerNode.outputVolume = 0.05

        do {
            try mic.start()
        } catch {
            print("[AudioBridge] Failed to start mic engine: \(error)")
        }
    }

    func stopTX() {
        guard isTXActive else { return }
        isTXActive = false
        micEngine?.inputNode.removeTap(onBus: 0)
        micEngine?.stop()
        micEngine = nil
        txConverter = nil
        txPcmBuffer = Data()

        // Restore RX volume
        audioEngine?.mainMixerNode.outputVolume = savedVolume
    }

    private func drainTXBuffer() {
        let bytesPerFrame = txFrameSize * 2
        while txPcmBuffer.count >= bytesPerFrame {
            let frameData = txPcmBuffer.prefix(bytesPerFrame)
            txPcmBuffer = Data(txPcmBuffer.dropFirst(bytesPerFrame))

            let encoded: Data?
            if codecType == .opus {
                encoded = opusEncoder?.encode(frameData)
            } else {
                encoded = speexEncoder?.encode(frameData)
            }

            if let encoded, let callback = onEncodedAudio {
                callback(encoded)
            }
        }
    }

    func setVolume(_ level: Float) {
        audioEngine?.mainMixerNode.outputVolume = level
    }

    func stop() {
        stopTX()
        isActive = false
        batchTimer?.cancel()
        batchTimer = nil
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        opusDecoder = nil
        opusEncoder = nil
        speexDecoder = nil
        speexEncoder = nil
        onEncodedAudio = nil
        rxPacketCount = 0
        pendingPcm = []
        pendingBytes = 0

        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

/// Upsample 8kHz Int16 PCM to 48kHz using linear interpolation (6x)
private func upsample8to48(_ input: Data) -> Data {
    let srcSamples = input.count / 2
    let dstSamples = srcSamples * 6
    var output = Data(count: dstSamples * 2)

    input.withUnsafeBytes { srcRaw in
        let src = srcRaw.bindMemory(to: Int16.self)
        output.withUnsafeMutableBytes { dstRaw in
            let dst = dstRaw.bindMemory(to: Int16.self)
            for i in 0..<(srcSamples - 1) {
                let s0 = Float(src[i])
                let s1 = Float(src[i + 1])
                for j in 0..<6 {
                    let t = Float(j) / 6.0
                    let interpolated = Int16(clamping: Int(s0 + (s1 - s0) * t))
                    dst[i * 6 + j] = interpolated
                }
            }
            let last = src[srcSamples - 1]
            for j in 0..<6 {
                dst[(srcSamples - 1) * 6 + j] = last
            }
        }
    }
    return output
}
