/*
 * SafeHardDecoder for Hello Chat / Tencent VAP.
 * Protects MediaTek hardware decoders (c2.mtk.avc.decoder) from BufferQueue
 * abandonment stalls by draining and deferring codec teardown off every UI/GL thread.
 *
 * Fix (2026-11-05): Catch BufferQueue-abandoned exceptions near clip end and
 * immediately fire onVideoComplete without waiting for the RELEASE_GRACE_MS delay.
 * This eliminates the "freeze at last frame" on devices where the codec surface
 * is released before the final buffer is consumed.
 */
package com.tencent.qgame.animplayer

import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.util.Log
import android.view.Surface
import com.tencent.qgame.animplayer.file.IFileContainer
import com.tencent.qgame.animplayer.util.ALog
import com.tencent.qgame.animplayer.util.MediaUtil
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class SafeHardDecoder(player: AnimPlayer) : Decoder(player), SurfaceTexture.OnFrameAvailableListener {

    companion object {
        private const val TAG = "${Constant.TAG}.SafeHardDecoder"

        /** Grace period so in-flight output buffers return to the BufferQueue before codec stop(). */
        private const val RELEASE_GRACE_MS = 350L

        /** One shared daemon thread for all codec teardown: no raw Thread + sleep per release. */
        private val releaseExecutor by lazy {
            Executors.newSingleThreadScheduledExecutor { r ->
                Thread(r, "vap-codec-release").apply { isDaemon = true }
            }
        }

        @Volatile private var activeReleaseFuture: java.util.concurrent.Future<*>? = null

        /**
         * Matches the "BufferQueue has been abandoned" message that appears when the
         * SurfaceTexture is released before the final codec output buffer is consumed.
         * This is the primary cause of the "freeze at last frame" on MediaTek devices.
         */
        private fun isBufferQueueAbandoned(e: Throwable): Boolean {
            val msg = e.message ?: e.cause?.message ?: ""
            return msg.contains("BufferQueue", ignoreCase = true) &&
                (msg.contains("abandon", ignoreCase = true) || msg.contains("dead", ignoreCase = true))
        }
    }

    private var surface: Surface? = null
    private var glTexture: SurfaceTexture? = null
    private val bufferInfo = MediaCodec.BufferInfo()

    // Written on the render thread / start(), read on decode thread.
    @Volatile private var needDestroy = false
    private val released = AtomicBoolean(false)

    private var videoWidth = 0
    private var videoHeight = 0
    private var alignWidth = 0
    private var alignHeight = 0
    private var needYUV = false
    private var outputFormat: MediaFormat? = null
    private var fixedFps: Int = 25

    override fun start(fileContainer: IFileContainer) {
        isStopReq = false
        needDestroy = false
        released.set(false)
        isRunning = true
        renderThread.handler?.post { startPlay(fileContainer) }
    }

    override fun onFrameAvailable(surfaceTexture: SurfaceTexture?) {
        if (isStopReq) return
        renderData()
    }

    private fun renderData() {
        renderThread.handler?.post {
            if (isStopReq) return@post
            try {
                glTexture?.apply {
                    updateTexImage()
                    render?.renderFrame()
                    player.pluginManager.onRendering()
                    render?.swapBuffers()
                }
            } catch (e: Throwable) {
                ALog.e(TAG, "render exception=$e", e)
            }
        }
    }

    private fun startPlay(fileContainer: IFileContainer) {
        // Await prior release completion so two MediaCodec instances never collide
        activeReleaseFuture?.let { f ->
            runCatching { f.get(300, TimeUnit.MILLISECONDS) }
            activeReleaseFuture = null
        }

        var extractor: MediaExtractor? = null
        var decoder: MediaCodec? = null
        val format: MediaFormat

        try {
            extractor = MediaUtil.getExtractor(fileContainer)
            val trackIndex = MediaUtil.selectVideoTrack(extractor)
            if (trackIndex < 0) throw RuntimeException("No video track found")
            extractor.selectTrack(trackIndex)
            format = extractor.getTrackFormat(trackIndex)

            if (MediaUtil.checkIsHevc(format) &&
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP ||
                    !MediaUtil.checkSupportCodec(MediaUtil.MIME_HEVC))
            ) {
                onFailed(
                    Constant.REPORT_ERROR_TYPE_HEVC_NOT_SUPPORT,
                    "${Constant.ERROR_MSG_HEVC_NOT_SUPPORT} sdk:${Build.VERSION.SDK_INT}"
                )
                release(null, extractor)
                return
            }

            videoWidth = format.getInteger(MediaFormat.KEY_WIDTH)
            videoHeight = format.getInteger(MediaFormat.KEY_HEIGHT)
            alignWidth = videoWidth
            alignHeight = videoHeight

            var waitRetries = 0
            while (player.animView.getSurfaceTexture() == null && waitRetries < 25) {
                try { Thread.sleep(20) } catch (_: Throwable) {}
                waitRetries++
            }

            try {
                if (!prepareRender(needYUV)) throw RuntimeException("render create fail")
            } catch (t: Throwable) {
                onFailed(Constant.REPORT_ERROR_TYPE_CREATE_RENDER, "${Constant.ERROR_MSG_CREATE_RENDER} e=$t")
                release(null, extractor)
                return
            }

            preparePlay(videoWidth, videoHeight)

            val configFps = player.configManager.config?.fps ?: 0
            val trackFps = if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                runCatching { format.getInteger(MediaFormat.KEY_FRAME_RATE) }.getOrDefault(0)
            } else 0
            fixedFps = when {
                configFps > 0 -> configFps
                trackFps > 0 -> trackFps
                else -> 25
            }
            speedControlUtil.setFixedPlaybackRate(fixedFps)

            render?.apply {
                glTexture = SurfaceTexture(getExternalTexture()).apply {
                    setOnFrameAvailableListener(this@SafeHardDecoder)
                    setDefaultBufferSize(videoWidth, videoHeight)
                }
                clearFrame()
            }
        } catch (e: Throwable) {
            ALog.e(TAG, "MediaExtractor exception e=$e", e)
            onFailed(Constant.REPORT_ERROR_TYPE_EXTRACTOR_EXC, "${Constant.ERROR_MSG_EXTRACTOR_EXC} e=$e")
            release(decoder, extractor)
            return
        }

        try {
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            decoder = MediaCodec.createDecoderByType(mime)
            if (needYUV) {
                format.setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
                )
                decoder.configure(format, null, null, 0)
            } else {
                surface = Surface(glTexture)
                decoder.configure(format, surface, null, 0)
            }
            decoder.start()
        } catch (e: Throwable) {
            ALog.e(TAG, "MediaCodec create fail e=$e", e)
            onFailed(Constant.REPORT_ERROR_TYPE_DECODE_EXC, "${Constant.ERROR_MSG_DECODE_EXC} e=$e")
            release(decoder, extractor)
            return
        }

        val d = decoder
        val x = extractor
        decodeThread.handler?.post { decode(d, x) }
    }

    private fun decode(decoder: MediaCodec, extractor: MediaExtractor) {
        val timeoutUsec = 10000L
        var inputDone = false
        var outputDone = false
        var frameIndex = 0
        var isLoop = false
        var emptyOutputCount = 0

        try {
            while (!outputDone) {
                if (isStopReq) {
                    ALog.i(TAG, "decode stop req")
                    break
                }

                if (!inputDone) {
                    val inputIndex = decoder.dequeueInputBuffer(timeoutUsec)
                    if (inputIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputIndex)
                        val sampleSize = if (inputBuffer != null) extractor.readSampleData(inputBuffer, 0) else -1
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inputIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val status = decoder.dequeueOutputBuffer(bufferInfo, timeoutUsec)
                val totalFrames = player.configManager.config?.totalFrames ?: 0
                when {
                    status == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (inputDone) {
                            emptyOutputCount++
                            // MediaTek / vendor bug safeguard: after input reaches EOS, if the decoder
                            // returns INFO_TRY_AGAIN_LATER consecutively or has decoded all frames,
                            // the stream is complete. Do not hang in a busy loop!
                            if (emptyOutputCount >= 5 || (totalFrames > 0 && frameIndex >= totalFrames)) {
                                Log.i(TAG, "decode: EOS reached via output buffer drain (frames=$frameIndex, total=$totalFrames)")
                                outputDone = true
                            }
                        }
                    }
                    status == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> outputFormat = decoder.outputFormat
                    status >= 0 -> {
                        emptyOutputCount = 0
                        var loop = 0
                        val isEosBuffer = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0)
                        val isLastFrame = (totalFrames > 0 && frameIndex + 1 >= totalFrames && inputDone)
                        if (isEosBuffer || isLastFrame) {
                            loop = --playLoop
                            player.playLoop = playLoop
                            outputDone = playLoop <= 0
                        }
                        val doRender = (!outputDone || bufferInfo.size > 0) && !isStopReq

                        if (doRender) speedControlUtil.preRender(bufferInfo.presentationTimeUs)
                        if (needYUV && doRender) yuvProcess(decoder, status)

                        // Always hand the buffer back, even when not rendering, so the
                        // BufferQueue never keeps an unreturned buffer at teardown.
                        decoder.releaseOutputBuffer(status, doRender && !needYUV)

                        if (frameIndex == 0 && !isLoop) onVideoStart()
                        player.pluginManager.onDecoding(frameIndex)
                        onVideoRender(frameIndex, player.configManager.config)
                        frameIndex++

                        if (outputDone && loop > 0 && !isStopReq) {
                            player.pluginManager.onLoopStart()
                            extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                            decoder.flush()
                            inputDone = false
                            outputDone = false
                            speedControlUtil.reset()
                            speedControlUtil.setFixedPlaybackRate(fixedFps)
                            frameIndex = 0
                            isLoop = true
                        }
                    }
                }
            }
        } catch (e: Throwable) {
            // FIX: BufferQueue abandonment near clip end — treat as a clean EOS rather than
            // an error. The codec surface is released before the final buffer is consumed on
            // some MediaTek and Qualcomm devices. Firing onVideoComplete immediately (without
            // waiting for RELEASE_GRACE_MS) eliminates the "freeze at last frame" symptom.
            if (isBufferQueueAbandoned(e)) {
                Log.w(TAG, "decode: BufferQueue abandoned near EOS — treating as clean completion (frameIndex=$frameIndex). e=$e")
                // Fall through to finally → release() which calls onVideoComplete
            } else {
                ALog.e(TAG, "decode exception=$e", e)
            }
        } finally {
            release(decoder, extractor)
        }
    }

    private fun yuvProcess(decoder: MediaCodec, outputIndex: Int) {
        val outputBuffer = decoder.getOutputBuffer(outputIndex) ?: return
        outputBuffer.position(bufferInfo.offset)
        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
        var yuvData = ByteArray(outputBuffer.remaining())
        outputBuffer.get(yuvData)
        if (yuvData.isEmpty()) return

        val yData = ByteArray(videoWidth * videoHeight)
        val uData = ByteArray(videoWidth * videoHeight / 4)
        val vData = ByteArray(videoWidth * videoHeight / 4)

        if (outputFormat?.getInteger(MediaFormat.KEY_COLOR_FORMAT) ==
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        ) {
            yuvData = yuv420spTop(yuvData)
        }

        yuvCopy(yuvData, 0, alignWidth, alignHeight, yData, videoWidth, videoHeight)
        yuvCopy(yuvData, alignWidth * alignHeight, alignWidth / 2, alignHeight / 2, uData, videoWidth / 2, videoHeight / 2)
        yuvCopy(yuvData, alignWidth * alignHeight * 5 / 4, alignWidth / 2, alignHeight / 2, vData, videoWidth / 2, videoHeight / 2)

        render?.setYUVData(videoWidth, videoHeight, yData, uData, vData)
        renderData()
    }

    private fun yuv420spTop(yuv420sp: ByteArray): ByteArray {
        val yuv420p = ByteArray(yuv420sp.size)
        val ySize = alignWidth * alignHeight
        System.arraycopy(yuv420sp, 0, yuv420p, 0, ySize)
        var i = ySize
        var j = ySize
        while (i < ySize * 3 / 2) {
            yuv420p[j] = yuv420sp[i]
            yuv420p[j + ySize / 4] = yuv420sp[i + 1]
            i += 2
            j++
        }
        return yuv420p
    }

    private fun yuvCopy(
        src: ByteArray, srcOffset: Int, inWidth: Int, inHeight: Int,
        dest: ByteArray, outWidth: Int, outHeight: Int
    ) {
        val rows = minOf(inHeight, outHeight)
        for (h in 0 until rows) {
            System.arraycopy(src, srcOffset + h * inWidth, dest, h * outWidth, outWidth)
        }
    }

    /**
     * Idempotent: safe to call from stop, EOS, error and failure paths.
     * Order matters: stop frame callbacks -> clear GL -> (grace delay) codec stop/release
     * -> Surface -> SurfaceTexture -> GL texture. Nothing blocking runs on render/UI threads.
     */
    private fun release(decoder: MediaCodec?, extractor: MediaExtractor?) {
        if (!released.compareAndSet(false, true)) return

        renderThread.handler?.post {
            val textureToRelease = glTexture
            val surfaceToRelease = surface
            val renderToRelease = render
            glTexture = null
            surface = null

            try {
                textureToRelease?.setOnFrameAvailableListener(null)
                renderToRelease?.clearFrame()
                renderToRelease?.swapBuffers()
                speedControlUtil.reset()
                player.pluginManager.onRelease()
            } catch (e: Throwable) {
                ALog.e(TAG, "release prep exception: $e", e)
            }

            // Immediately mark stopped and fire onVideoComplete so UI hides the frame instantaneously!
            isRunning = false
            onVideoComplete()

            activeReleaseFuture = releaseExecutor.schedule({
                try { decoder?.stop() } catch (e: Throwable) { Log.w(TAG, "decoder.stop: $e") }
                try { decoder?.release() } catch (e: Throwable) { Log.w(TAG, "decoder.release: $e") }
                try { extractor?.release() } catch (e: Throwable) { Log.w(TAG, "extractor.release: $e") }
                try { surfaceToRelease?.release() } catch (e: Throwable) { Log.w(TAG, "surface.release: $e") }
                try { textureToRelease?.release() } catch (e: Throwable) { Log.w(TAG, "texture.release: $e") }
                renderThread.handler?.post {
                    try { renderToRelease?.releaseTexture() } catch (e: Throwable) { Log.w(TAG, "releaseTexture: $e") }
                    if (needDestroy) destroyInner()
                }
            }, 50L, TimeUnit.MILLISECONDS)
        }
    }

    override fun destroy() {
        if (isRunning) {
            needDestroy = true
            stop()
        } else {
            destroyInner()
        }
    }

    private fun destroyInner() {
        renderThread.handler?.post {
            player.pluginManager.onDestroy()
            render?.destroyRender()
            render = null
            onVideoDestroy()
            destroyThread()
        }
    }
}
