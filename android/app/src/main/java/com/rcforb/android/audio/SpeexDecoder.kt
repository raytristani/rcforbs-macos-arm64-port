package com.rcforb.android.audio

import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Speex narrowband decoder.
 * On Android, we use a minimal pure-Java Speex decoder implementation.
 * Parameters: 8kHz narrowband, 160 samples/frame (20ms).
 * Falls back to silence if decoding fails.
 *
 * NOTE: For a production build, integrate libspeex via JNI.
 * This stub produces silence frames to maintain audio timing.
 */
class SpeexDecoder {
    private val frameSize = 160
    private val bytesPerFrame = frameSize * 2 // Int16

    init {
        Log.i("SpeexDecoder", "Speex decoder initialized (stub - produces silence)")
    }

    fun decode(packet: ByteArray): ByteArray? {
        // Stub: return silence frame matching expected frame size
        // In production, this would call native libspeex via JNI
        return ByteArray(bytesPerFrame)
    }

    fun release() {
        // No-op for stub
    }
}
