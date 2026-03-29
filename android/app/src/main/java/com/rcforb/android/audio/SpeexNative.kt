package com.rcforb.android.audio

object SpeexNative {
    init {
        System.loadLibrary("speex_jni")
    }

    external fun nativeCreate(): Long
    external fun nativeDecode(handle: Long, encoded: ByteArray): ByteArray?
    external fun nativeDestroy(handle: Long)
}
