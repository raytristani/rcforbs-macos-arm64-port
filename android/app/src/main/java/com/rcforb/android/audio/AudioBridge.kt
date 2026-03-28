package com.rcforb.android.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import kotlinx.coroutines.*
import java.nio.ByteBuffer
import java.nio.ByteOrder

enum class CodecType { OPUS, SPEEX }

class AudioBridge {
    private var codecType = CodecType.OPUS
    private var isActive = false
    private var rxPacketCount = 0

    private var audioTrack: AudioTrack? = null
    private val sampleRate = 48000

    private var opusDecoder: OpusDecoder? = null
    private var speexDecoder: SpeexDecoder? = null

    private val pendingPcm = mutableListOf<ByteArray>()
    private val batchFrames = 4
    private val audioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var batchJob: Job? = null

    var onEncodedAudio: ((ByteArray) -> Unit)? = null

    fun start(codec: CodecType = CodecType.OPUS) {
        if (isActive) return
        codecType = codec
        isActive = true
        rxPacketCount = 0
        pendingPcm.clear()

        if (codec == CodecType.OPUS) {
            opusDecoder = OpusDecoder()
            speexDecoder = null
        } else {
            speexDecoder = SpeexDecoder()
            opusDecoder = null
        }

        setupAudioTrack()
        Log.i("AudioBridge", "Started with $codec codec")
    }

    private fun setupAudioTrack() {
        val bufSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufSize * 4)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()
    }

    fun pushRXAudio(data: ByteArray) {
        if (!isActive) return

        val pcm = if (codecType == CodecType.OPUS) {
            opusDecoder?.decode(data)
        } else {
            speexDecoder?.decode(data)
        } ?: return

        if (pcm.isEmpty()) return

        rxPacketCount++
        if (rxPacketCount <= 3) {
            Log.i("AudioBridge", "RX packet #$rxPacketCount: ${data.size} encoded -> ${pcm.size} PCM bytes")
        }

        val outputPcm = if (codecType == CodecType.SPEEX) {
            upsample8to48(pcm)
        } else {
            pcm
        }

        synchronized(pendingPcm) {
            pendingPcm.add(outputPcm)
            if (pendingPcm.size >= batchFrames) {
                flushToPlayer()
            } else if (batchJob == null) {
                batchJob = audioScope.launch {
                    delay(40)
                    synchronized(pendingPcm) { flushToPlayer() }
                }
            }
        }
    }

    private fun flushToPlayer() {
        batchJob?.cancel()
        batchJob = null

        if (pendingPcm.isEmpty()) return

        var totalSize = 0
        for (chunk in pendingPcm) totalSize += chunk.size
        val merged = ByteArray(totalSize)
        var offset = 0
        for (chunk in pendingPcm) {
            System.arraycopy(chunk, 0, merged, offset, chunk.size)
            offset += chunk.size
        }
        pendingPcm.clear()

        audioTrack?.write(merged, 0, merged.size)
    }

    fun setVolume(level: Float) {
        audioTrack?.setVolume(level)
    }

    fun stop() {
        Log.i("AudioBridge", "Stopped. Total RX packets decoded: $rxPacketCount")
        isActive = false
        batchJob?.cancel()
        batchJob = null
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        opusDecoder = null
        speexDecoder = null
        onEncodedAudio = null
        rxPacketCount = 0
        pendingPcm.clear()
    }

    companion object {
        fun upsample8to48(input: ByteArray): ByteArray {
            val srcSamples = input.size / 2
            val dstSamples = srcSamples * 6
            val output = ByteArray(dstSamples * 2)

            val srcBuf = ByteBuffer.wrap(input).order(ByteOrder.LITTLE_ENDIAN)
            val dstBuf = ByteBuffer.wrap(output).order(ByteOrder.LITTLE_ENDIAN)

            val src = ShortArray(srcSamples) { srcBuf.short }

            for (i in 0 until srcSamples - 1) {
                val s0 = src[i].toFloat()
                val s1 = src[i + 1].toFloat()
                for (j in 0 until 6) {
                    val t = j / 6.0f
                    val interpolated = (s0 + (s1 - s0) * t).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
                    dstBuf.putShort((i * 6 + j) * 2, interpolated)
                }
            }
            val last = src[srcSamples - 1]
            for (j in 0 until 6) {
                dstBuf.putShort(((srcSamples - 1) * 6 + j) * 2, last)
            }
            return output
        }
    }
}
