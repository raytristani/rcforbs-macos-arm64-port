#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include "speex/speex.h"
#include "speex/speex_bits.h"

typedef struct {
    void *dec_state;
    SpeexBits bits;
    int frame_size;
} SpeexHandle;

JNIEXPORT jlong JNICALL
Java_com_rcforb_android_audio_SpeexNative_nativeCreate(JNIEnv *env, jclass clazz) {
    SpeexHandle *h = (SpeexHandle *)calloc(1, sizeof(SpeexHandle));
    if (!h) return 0;

    h->dec_state = speex_decoder_init(&speex_nb_mode);
    speex_bits_init(&h->bits);

    int enh = 1;
    speex_decoder_ctl(h->dec_state, SPEEX_SET_ENH, &enh);
    speex_decoder_ctl(h->dec_state, SPEEX_GET_FRAME_SIZE, &h->frame_size);

    return (jlong)(intptr_t)h;
}

JNIEXPORT jbyteArray JNICALL
Java_com_rcforb_android_audio_SpeexNative_nativeDecode(JNIEnv *env, jclass clazz,
        jlong handle, jbyteArray encoded) {
    SpeexHandle *h = (SpeexHandle *)(intptr_t)handle;
    if (!h || !h->dec_state) return NULL;

    jsize in_len = (*env)->GetArrayLength(env, encoded);
    jbyte *in_data = (*env)->GetByteArrayElements(env, encoded, NULL);

    speex_bits_read_from(&h->bits, (const char *)in_data, in_len);
    (*env)->ReleaseByteArrayElements(env, encoded, in_data, JNI_ABORT);

    // Decode all frames in the packet
    int total_samples = 0;
    short output[160 * 10]; // max 10 frames
    while (speex_bits_remaining(&h->bits) > 10) {
        int ret = speex_decode_int(h->dec_state, &h->bits, output + total_samples);
        if (ret != 0) break;
        total_samples += h->frame_size;
        if (total_samples >= 160 * 10) break;
    }

    if (total_samples == 0) return NULL;

    int out_bytes = total_samples * 2;
    jbyteArray result = (*env)->NewByteArray(env, out_bytes);
    (*env)->SetByteArrayRegion(env, result, 0, out_bytes, (jbyte *)output);
    return result;
}

JNIEXPORT void JNICALL
Java_com_rcforb_android_audio_SpeexNative_nativeDestroy(JNIEnv *env, jclass clazz, jlong handle) {
    SpeexHandle *h = (SpeexHandle *)(intptr_t)handle;
    if (!h) return;
    if (h->dec_state) {
        speex_bits_destroy(&h->bits);
        speex_decoder_destroy(h->dec_state);
    }
    free(h);
}
