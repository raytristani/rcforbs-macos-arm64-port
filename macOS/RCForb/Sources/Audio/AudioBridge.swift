import Foundation
import AVFoundation

enum CodecType {
    case opus
    case speex
}

/// Audio bridge ported from audio-bridge.ts
/// Decodes network audio and plays via AVAudioEngine.
class AudioBridge {
    private var codecType: CodecType = .opus
    private var isActive = false
    private var rxPacketCount = 0

    // Audio engine for playback
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 48000
    private let format: AVAudioFormat

    // Opus decoder
    private var opusDecoder: OpusDecoder?
    // Speex decoder
    private var speexDecoder: SpeexDecoder?

    // Batching
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
            speexDecoder = nil
        } else {
            speexDecoder = SpeexDecoder()
            opusDecoder = nil
        }

        setupAudioEngine()
        print("[AudioBridge] Started with \(codecType) codec")
    }

    private func setupAudioEngine() {
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
        if rxPacketCount <= 3 {
            print("[AudioBridge] RX packet #\(rxPacketCount): \(data.count) encoded -> \(pcm.count) PCM bytes")
        }

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

        // Convert Int16 PCM to Float32 for AVAudioPCMBuffer
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

    func stop() {
        print("[AudioBridge] Stopped. Total RX packets decoded: \(rxPacketCount)")
        isActive = false
        batchTimer?.cancel()
        batchTimer = nil
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        opusDecoder = nil
        speexDecoder = nil
        onEncodedAudio = nil
        rxPacketCount = 0
        pendingPcm = []
        pendingBytes = 0
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
