package com.rcforb.android.audio

import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Speex narrowband encoder using native libspeex via JNI.
 * Downsamples 48kHz input to 8kHz before encoding.
 */
class SpeexEncoder {
    private var handle: Long = 0L
    private val frameSize = 160 // 8kHz * 20ms

    init {
        try {
            handle = SpeexNative.nativeCreateEncoder(8) // quality 8
            Log.i("SpeexEncoder", "Native Speex encoder initialized (handle=$handle)")
        } catch (e: Exception) {
            Log.e("SpeexEncoder", "Failed to init native Speex encoder: ${e.message}")
            handle = 0L
        }
    }

    fun encode(pcm48k: ByteArray): ByteArray? {
        if (handle == 0L) return null

        // Downsample 48kHz to 8kHz (6:1)
        val pcm8k = downsample48to8(pcm48k)

        // Encode one frame (160 samples = 320 bytes at 8kHz)
        if (pcm8k.size < frameSize * 2) return null
        return SpeexNative.nativeEncode(handle, pcm8k.copyOf(frameSize * 2))
    }

    fun release() {
        if (handle != 0L) {
            SpeexNative.nativeDestroyEncoder(handle)
            handle = 0L
        }
    }

    private fun downsample48to8(input: ByteArray): ByteArray {
        val srcSamples = input.size / 2
        val dstSamples = srcSamples / 6
        val output = ByteArray(dstSamples * 2)

        val srcBuf = ByteBuffer.wrap(input).order(ByteOrder.LITTLE_ENDIAN)
        val dstBuf = ByteBuffer.wrap(output).order(ByteOrder.LITTLE_ENDIAN)

        for (i in 0 until dstSamples) {
            dstBuf.putShort(i * 2, srcBuf.getShort(i * 6 * 2))
        }
        return output
    }
}
