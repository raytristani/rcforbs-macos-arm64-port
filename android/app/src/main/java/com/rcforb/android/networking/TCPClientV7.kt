package com.rcforb.android.networking

import android.util.Log
import com.rcforb.android.protocol.*
import kotlinx.coroutines.*
import java.io.InputStream
import java.io.OutputStream
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder

class TCPClientV7(private val voipPort: Int) {
    private var cmdSocket: Socket? = null
    private var audioSocket: Socket? = null
    private var cmdOut: OutputStream? = null
    private var audioOut: OutputStream? = null
    private var isConnectedFlag = false
    private var isDataFlowingFlag = false
    private var lastServerData = System.currentTimeMillis()
    private var cmdBuffer = StringBuilder()
    private var audioBuffer = ByteArray(0)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var jobs = mutableListOf<Job>()

    var onAudio: ((ByteArray) -> Unit)? = null
    var onCommand: ((String) -> Unit)? = null
    var onControl: ((Byte) -> Unit)? = null
    var onDisconnected: (() -> Unit)? = null

    private var dataFlowContinuation: CancellableContinuation<Boolean>? = null

    val isConnected: Boolean get() = isConnectedFlag

    suspend fun connect(host: String, port: Int): Boolean = withContext(Dispatchers.IO) {
        try {
            val cmd = Socket(host, port)
            cmd.soTimeout = 500
            cmdSocket = cmd
            cmdOut = cmd.getOutputStream()

            val audio = Socket(host, voipPort)
            audio.soTimeout = 500
            audioSocket = audio
            audioOut = audio.getOutputStream()

            isConnectedFlag = true
            lastServerData = System.currentTimeMillis()

            startHeartbeat()
            startCmdReceive()
            startAudioReceive()
            true
        } catch (e: Exception) {
            Log.e("TCPv7", "Connect failed", e)
            false
        }
    }

    fun disconnect() {
        sendRawCmd(byteArrayOf(ControlByte.USEROUT))
        stopAll()
        onDisconnected?.invoke()
    }

    private fun handleDisconnect() {
        if (!isConnectedFlag) return
        stopAll()
        onDisconnected?.invoke()
    }

    private fun stopAll() {
        isConnectedFlag = false
        isDataFlowingFlag = false
        jobs.forEach { it.cancel() }
        jobs.clear()
        try { cmdSocket?.close() } catch (_: Exception) {}
        try { audioSocket?.close() } catch (_: Exception) {}
        cmdSocket = null; audioSocket = null
        cmdOut = null; audioOut = null
    }

    fun sendCommandString(text: String) {
        var cmd = text
        if (cmd == "radio::request-state") cmd = "set protocol rcs"
        cmd = cmd.replace("radio::", "post::")
        cmd = cmd.replace("post::raw::", "k3term::")
        try { cmdOut?.write("$cmd\n".toByteArray(Charsets.UTF_8)) } catch (_: Exception) {}
    }

    fun sendRawCmd(data: ByteArray) {
        try { cmdOut?.write(data) } catch (_: Exception) {}
    }

    fun sendPTT(on: Boolean) {
        sendRawCmd(byteArrayOf(if (on) ControlByte.PTT else ControlByte.PTT_OFF))
    }

    fun sendAudio(data: ByteArray) {
        val out = audioOut ?: return
        try {
            val header = ByteBuffer.allocate(10).order(ByteOrder.LITTLE_ENDIAN)
            header.putInt(data.size)
            header.putInt(0)
            header.putShort(0)
            out.write(header.array())
            out.write(data)
        } catch (_: Exception) {}
    }

    fun sendSessionLogin(user: String, passwordMD5: String) {
        val out = audioOut ?: return
        try {
            val sessionStr = "${user.lowercase()},$passwordMD5"
            val strBytes = sessionStr.toByteArray(Charsets.US_ASCII)
            val buf = ByteBuffer.allocate(64).order(ByteOrder.LITTLE_ENDIAN)
            buf.putInt(54)
            buf.putInt(strBytes.size)
            buf.put(strBytes)
            // Pad remaining
            val remaining = 64 - 8 - strBytes.size
            if (remaining > 0) buf.put(ByteArray(remaining))
            out.write(buf.array())
        } catch (_: Exception) {}
    }

    private fun startCmdReceive() {
        val job = scope.launch {
            val buf = ByteArray(65536)
            val input: InputStream = cmdSocket?.getInputStream() ?: return@launch
            while (isActive && isConnectedFlag) {
                try {
                    val len = input.read(buf)
                    if (len > 0) {
                        processCmdData(String(buf, 0, len, Charsets.UTF_8))
                    } else if (len == -1) {
                        handleDisconnect()
                        break
                    }
                } catch (_: java.net.SocketTimeoutException) {
                    // Normal
                } catch (e: Exception) {
                    if (isConnectedFlag) handleDisconnect()
                    break
                }
            }
        }
        jobs.add(job)
    }

    private fun processCmdData(data: String) {
        lastServerData = System.currentTimeMillis()
        if (!isDataFlowingFlag) {
            isDataFlowingFlag = true
            dataFlowContinuation?.resumeWith(Result.success(true))
            dataFlowContinuation = null
        }

        cmdBuffer.append(data)
        val lines = cmdBuffer.toString().split("\n").toMutableList()
        cmdBuffer = StringBuilder(lines.removeAt(lines.size - 1))

        for (line in lines) {
            val trimmed = line.trim()
            if (trimmed.isNotEmpty()) {
                onCommand?.invoke(trimmed)
            }
        }
    }

    private fun startAudioReceive() {
        val job = scope.launch {
            val buf = ByteArray(65536)
            val input: InputStream = audioSocket?.getInputStream() ?: return@launch
            while (isActive && isConnectedFlag) {
                try {
                    val len = input.read(buf)
                    if (len > 0) {
                        processAudioData(buf.copyOfRange(0, len))
                    } else if (len == -1) {
                        break
                    }
                } catch (_: java.net.SocketTimeoutException) {
                    // Normal
                } catch (_: Exception) {
                    break
                }
            }
        }
        jobs.add(job)
    }

    private fun processAudioData(data: ByteArray) {
        audioBuffer += data

        while (audioBuffer.size >= 10) {
            val bb = ByteBuffer.wrap(audioBuffer, 0, 4).order(ByteOrder.LITTLE_ENDIAN)
            val payloadLen = bb.int

            if (payloadLen == 0) {
                audioBuffer = audioBuffer.copyOfRange(4, audioBuffer.size)
                continue
            }
            if (payloadLen == 54) {
                if (audioBuffer.size < 62) break
                audioBuffer = audioBuffer.copyOfRange(62, audioBuffer.size)
                continue
            }
            if (payloadLen < 0 || payloadLen > 8192) {
                audioBuffer = audioBuffer.copyOfRange(1, audioBuffer.size)
                continue
            }

            val totalLen = 10 + payloadLen
            if (audioBuffer.size < totalLen) break

            if (payloadLen in 1..18) {
                val pttByte = audioBuffer[4]
                if (pttByte.toInt() == 2) {
                    onControl?.invoke(ControlByte.PTT)
                } else if (pttByte.toInt() == 0 || pttByte.toInt() == 1) {
                    onControl?.invoke(ControlByte.PTT_OFF)
                }
            } else if (payloadLen >= 19) {
                val audioPayload = audioBuffer.copyOfRange(10, totalLen)
                onAudio?.invoke(audioPayload)
            }

            audioBuffer = audioBuffer.copyOfRange(totalLen, audioBuffer.size)
        }
    }

    private fun startHeartbeat() {
        val hbJob = scope.launch {
            while (isActive && isConnectedFlag) {
                sendCommandString("post::heartbeat::${System.currentTimeMillis()}")
                sendCommandString("post::check::cantune")
                delay(HEARTBEAT_INTERVAL_MS)
            }
        }
        jobs.add(hbJob)

        val imaJob = scope.launch {
            while (isActive && isConnectedFlag) {
                delay(2000)
                val out = audioOut ?: continue
                try {
                    val ima = ByteBuffer.allocate(13).order(ByteOrder.LITTLE_ENDIAN)
                    ima.putInt(3)
                    ima.put(2)
                    ima.put(ByteArray(5))
                    ima.put("IMA".toByteArray(Charsets.US_ASCII))
                    out.write(ima.array())
                } catch (_: Exception) {}
            }
        }
        jobs.add(imaJob)

        val toJob = scope.launch {
            while (isActive && isConnectedFlag) {
                delay(1000)
                if (System.currentTimeMillis() - lastServerData > HEARTBEAT_TIMEOUT_MS) {
                    Log.w("TCPv7", "Heartbeat timeout")
                    handleDisconnect()
                    break
                }
            }
        }
        jobs.add(toJob)
    }

    suspend fun waitForDataFlow(timeoutMs: Long = 8000): Boolean {
        if (isDataFlowingFlag) return true
        return withTimeoutOrNull(timeoutMs) {
            suspendCancellableCoroutine { cont ->
                dataFlowContinuation = cont
            }
        } ?: false
    }
}
