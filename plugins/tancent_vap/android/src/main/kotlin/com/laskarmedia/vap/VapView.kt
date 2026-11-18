package com.laskarmedia.vap

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.LruCache
import android.view.View
import android.widget.FrameLayout
import com.tencent.qgame.animplayer.AnimConfig
import com.tencent.qgame.animplayer.AnimPlayer
import com.tencent.qgame.animplayer.AnimView
import com.tencent.qgame.animplayer.SafeHardDecoder
import com.tencent.qgame.animplayer.file.IFileContainer
import com.tencent.qgame.animplayer.inter.IAnimListener
import com.tencent.qgame.animplayer.inter.IFetchResource
import com.tencent.qgame.animplayer.mix.Resource
import com.tencent.qgame.animplayer.util.ScaleType
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

private const val TAG = "SafeAnimView"

class SafeAnimView(context: Context) : AnimView(context) {
    private var isDestroying = false
    @Volatile var isSurfaceAvailable = false
        private set
    private val surfaceCallbacks = mutableListOf<() -> Unit>()

    fun addOnSurfaceAvailableCallback(cb: () -> Unit) {
        if (isSurfaceAvailable) {
            cb()
        } else {
            surfaceCallbacks.add(cb)
        }
    }

    // Reflection done once, not on every startPlay.
    private val animPlayer: AnimPlayer? by lazy {
        try {
            AnimView::class.java.getDeclaredField("player")
                .apply { isAccessible = true }
                .get(this) as? AnimPlayer
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to reflect AnimPlayer: $e", e)
            null
        }
    }

    init {
        installSafeDecoder()
    }

    private fun installSafeDecoder() {
        val p = animPlayer ?: return
        if (p.decoder !is SafeHardDecoder) {
            p.decoder = SafeHardDecoder(p)
        }
    }

    override fun startPlay(fileContainer: IFileContainer) {
        installSafeDecoder()
        super.startPlay(fileContainer)
    }

    override fun startPlay(file: File) {
        installSafeDecoder()
        val p = animPlayer
        if (p != null && p.isRunning()) {
            Log.w(TAG, "startPlay: player is running, stopping previous clip before starting")
            runCatching { stopPlay() }
        }
        super.startPlay(file)
    }

    override fun startPlay(assetManager: android.content.res.AssetManager, assetsPath: String) {
        installSafeDecoder()
        super.startPlay(assetManager, assetsPath)
    }

    override fun onSurfaceTextureAvailable(surface: android.graphics.SurfaceTexture, width: Int, height: Int) {
        super.onSurfaceTextureAvailable(surface, width, height)
        isSurfaceAvailable = true
        Log.i(TAG, "onSurfaceTextureAvailable: surface ready ($width x $height)")
        val cbs = ArrayList(surfaceCallbacks)
        surfaceCallbacks.clear()
        cbs.forEach { runCatching { it() } }
    }

    override fun onSurfaceTextureDestroyed(surface: android.graphics.SurfaceTexture): Boolean {
        isSurfaceAvailable = false
        // DO NOT call super.onSurfaceTextureDestroyed(surface) as AnimView posts removeAllViews,
        // prematurely destroying InnerTextureView. Lifecycle cleanup is safely handled by safeDestroy().
        return true
    }

    // Detach must not destroy the decoder; safeDestroy() owns teardown.
    override fun onDetachedFromWindow() {}

    override fun removeAllViews() {
        if (isDestroying) {
            super.removeAllViews()
        } else {
            Log.d(TAG, "removeAllViews ignored to keep warm InnerTextureView surface alive")
        }
    }

    override fun removeView(view: View?) {
        super.removeView(view)
    }

    fun safeDestroy() {
        isDestroying = true
        surfaceCallbacks.clear()
        animPlayer?.let { p ->
            p.isDetachedFromWindow = true
            runCatching { p.decoder?.destroy() }
                .onFailure { Log.w(TAG, "decoder.destroy: $it") }
            runCatching {
                p.audioPlayer?.stop()
                p.audioPlayer?.destroy()
            }.onFailure { Log.w(TAG, "audioPlayer cleanup: $it") }
        }
        runCatching { super.removeAllViews() }
    }
}

class VapViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    @Suppress("UNCHECKED_CAST")
    override fun create(context: Context, id: Int, args: Any?): PlatformView =
        VapView(context, args as? Map<String, Any?>, messenger, id)
}

@OptIn(DelicateCoroutinesApi::class)
class VapView(
    context: Context, params: Map<String, Any?>?, messenger: BinaryMessenger, id: Int
) : PlatformView, MethodChannel.MethodCallHandler {

    private val frameLayout = FrameLayout(context)
    private val animView = SafeAnimView(context)
    private val channel = MethodChannel(messenger, "vap_view_$id")
    private val mainHandler = Handler(Looper.getMainLooper())

    private val vapTagContents = mutableMapOf<String, Map<String, String>>()
    private var completionWatchdog: Runnable? = null
    private var detectedDurationMs = 0L
    @Volatile private var hasCompleted = false
    @Volatile private var isDisposed = false
    @Volatile private var isPlayingActive = false
    private var currentPlayId: String? = null
    private var currentTicket: Int = 0
    private var ticketCounter: Int = 0

    init {
        applyScaleType(params?.get("scaleType") as? String)
        channel.setMethodCallHandler(this)
        frameLayout.addView(
            animView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        animView.addOnSurfaceAvailableCallback {
            invoke("onSurfaceReady", null)
        }

        // Trigger TextureView preparation immediately so surface is created as soon as attached/measured
        animView.prepareTextureView()

        animView.setMute((params?.get("mute") as? Boolean) ?: false)
        (params?.get("loop") as? Int)?.let { animView.setLoop(it) }

        @Suppress("UNCHECKED_CAST")
        (params?.get("vapTagContents") as? Map<String, Map<String, String>>)?.let { map ->
            vapTagContents.putAll(map)
            for ((tag, content) in map) {
                val value = content["contentValue"]
                val type = content["contentType"]
                if (type == "image_url" && !value.isNullOrEmpty()) {
                    handleUrlImage(value, tag) {}
                }
            }
        }

        animView.setFetchResource(object : IFetchResource {
            override fun fetchImage(resource: Resource, result: (Bitmap?) -> Unit) {
                val tag = resource.tag
                val map = vapTagContents[tag]
                    ?: vapTagContents["user"]
                    ?: vapTagContents["avatar"]
                    ?: vapTagContents["headimg"]
                val value = map?.get("contentValue")
                val type = map?.get("contentType")
                if (!value.isNullOrEmpty() && !type.isNullOrEmpty()) {
                    handleVapTagContent(value, type, tag) { bitmap ->
                        result(bitmap ?: getDefaultAvatarBitmap())
                    }
                } else {
                    result(getDefaultAvatarBitmap())
                }
            }

            override fun fetchText(resource: Resource, result: (String?) -> Unit) {
                result(vapTagContents[resource.tag]?.get("contentValue"))
            }

            override fun releaseResource(resources: List<Resource>) {}
        })

        animView.setAnimListener(object : IAnimListener {
            override fun onVideoConfigReady(config: AnimConfig): Boolean {
                detectedDurationMs =
                    if (config.fps > 0) config.totalFrames * 1000L / config.fps else 0L
                val map = mapOf(
                    "width" to config.width, "height" to config.height,
                    "fps" to config.fps, "totalFrames" to config.totalFrames,
                    "videoHeight" to config.videoHeight, "videoWidth" to config.videoWidth,
                    "isMix" to config.isMix, "orien" to config.orien, "version" to config.version
                )
                invoke("onVideoConfigReady", mapOf("config" to map))
                return super.onVideoConfigReady(config)
            }

            override fun onFailed(errorType: Int, errorMsg: String?) {
                cancelWatchdog()
                isPlayingActive = false
                val ticket = currentTicket
                val currentId = currentPlayId
                val deviceModel = "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}"
                Log.e("VAP_TRACE", "onFail: id=$currentId, ticket=$ticket, code=$errorType, msg=$errorMsg, device=$deviceModel")
                // FIX: postAtFrontOfQueue bypasses the Choreographer sync barrier so the
                // alpha=0 hide and Dart callback are not delayed by pending sync messages.
                mainHandler.postAtFrontOfQueue {
                    if (isDisposed) return@postAtFrontOfQueue
                    animView.alpha = 0f
                    animView.visibility = View.INVISIBLE
                    channel.invokeMethod(
                        "onFailed",
                        mapOf(
                            "errorCode" to errorType,
                            "errorMsg" to errorMsg,
                            "errorType" to "VIDEO_PLAYBACK_ERROR",
                            "device" to deviceModel,
                            "ticket" to ticket,
                            "id" to currentId
                        )
                    )
                }
            }

            override fun onVideoComplete() = dispatchVideoComplete()

            override fun onVideoDestroy() {
                dispatchVideoComplete()
                invoke("onVideoDestroy", mapOf("ticket" to currentTicket, "id" to currentPlayId))
            }

            override fun onVideoRender(frameIndex: Int, config: AnimConfig?) {
                if (config != null && config.totalFrames > 0 && frameIndex >= config.totalFrames - 1) {
                    dispatchVideoComplete()
                }
            }

            override fun onVideoStart() {
                hasCompleted = false
                isPlayingActive = true
                cancelWatchdog()
                val currentId = currentPlayId
                val ticket = currentTicket
                // Set alpha = 1f right here on frame 0 to avoid any stale-frame glitch during TTFF decode
                mainHandler.postAtFrontOfQueue {
                    if (!isDisposed) {
                        animView.visibility = View.VISIBLE
                        animView.alpha = 1f
                    }
                }
                if (detectedDurationMs > 0) {
                    val r = Runnable {
                        Log.w("VAP_TRACE", "watchdog firing: id=$currentId, ticket=$ticket, duration=${detectedDurationMs}ms elapsed, forcing completion")
                        dispatchVideoComplete()
                    }
                    completionWatchdog = r
                    mainHandler.postDelayed(r, detectedDurationMs + 1500L)
                }
                val deviceModel = "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}"
                Log.i("VAP_TRACE", "onStart: id=$currentId, ticket=$ticket, device=$deviceModel")
                invoke("onVideoStart", mapOf("device" to deviceModel, "ticket" to ticket, "id" to currentId))
            }
        })

        // Initially idle, warm and ready with near-zero alpha to guarantee surface creation on attach
        animView.alpha = 0.001f
        animView.visibility = View.VISIBLE

        // Start playback only after listeners/resources are registered
        (params?.get("filePath") as? String)?.let { playFile(it, params?.get("id") as? String, params?.get("ticket") as? Int, null) }
        (params?.get("assetName") as? String)?.let { playAsset(it, context, null) }
    }

    private fun invoke(method: String, args: Any?) {
        mainHandler.post { if (!isDisposed) channel.invokeMethod(method, args) }
    }

    private fun cancelWatchdog() {
        completionWatchdog?.let(mainHandler::removeCallbacks)
        completionWatchdog = null
    }

    private var pendingStartRunnable: Runnable? = null
    private var onReleaseCallback: (() -> Unit)? = null

    private fun cancelPendingStart() {
        pendingStartRunnable?.let(mainHandler::removeCallbacks)
        pendingStartRunnable = null
        onReleaseCallback = null
    }

    private fun dispatchVideoComplete() {
        if (hasCompleted || isDisposed) return
        hasCompleted = true
        isPlayingActive = false
        cancelWatchdog()
        val completedId = currentPlayId
        val ticket = currentTicket
        Log.i("VAP_TRACE", "onComplete: id=$completedId, ticket=$ticket")
        // FIX: postAtFrontOfQueue bypasses the Choreographer sync barrier.
        // This ensures alpha=0 (hide last frame) and the Dart onVideoComplete callback
        // are not delayed by pending sync messages — the primary cause of the
        // "freeze at end" the user reported.
        mainHandler.postAtFrontOfQueue {
            if (isDisposed) return@postAtFrontOfQueue
            animView.alpha = 0f
            animView.visibility = View.INVISIBLE
            channel.invokeMethod("onVideoComplete", mapOf("ticket" to ticket, "id" to completedId))

            // Trigger gated start if waiting for codec release
            val cb = onReleaseCallback
            if (cb != null) {
                cancelPendingStart()
                cb()
            }
        }
    }

    override fun getView(): View = frameLayout

    override fun dispose() {
        if (isDisposed) return
        isDisposed = true
        isPlayingActive = false
        cancelPendingStart()
        cancelWatchdog()
        mainHandler.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
        vapTagContents.clear()
        runCatching { animView.stopPlay() }.onFailure { Log.e("VapView", "stopPlay: $it") }
        runCatching {
            animView.safeDestroy()
            frameLayout.removeAllViews()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (isDisposed) { result.success(null); return }
        when (call.method) {
            "dispose" -> { dispose(); result.success(null) }
            "isReady" -> {
                val ready = animView.isSurfaceAvailable
                if (!ready) {
                    animView.prepareTextureView()
                }
                result.success(ready)
            }
            "playFile" -> playFile(
                call.argument<String>("filePath"),
                call.argument<String>("id"),
                call.argument<Int>("ticket"),
                result
            )
            "playAsset" -> playAsset(call.argument<String>("assetName"), frameLayout.context, result)
            "stop" -> { 
                cancelPendingStart()
                isPlayingActive = false
                animView.stopPlay()
                animView.alpha = 0f
                animView.visibility = View.INVISIBLE
                result.success(null) 
            }
            "setLoop" -> { animView.setLoop(call.argument<Int>("loop") ?: 1); result.success(null) }
            "setMute" -> { animView.setMute(call.argument<Boolean>("mute") ?: false); result.success(null) }
            "setScaleType" -> { applyScaleType(call.argument<String>("scaleType")); result.success(null) }
            "setVapTagContent" -> {
                val tag = call.argument<String>("tag")
                val content = call.argument<Map<String, String>>("content")
                if (tag != null && content != null) {
                    vapTagContents[tag] = content
                    val value = content["contentValue"]
                    val type = content["contentType"]
                    if (type == "image_url" && !value.isNullOrEmpty()) {
                        handleUrlImage(value, tag) {}
                    }
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Tag and content cannot be null", null)
                }
            }
            "setVapTagContents" -> {
                val contents = call.argument<Map<String, Map<String, String>>>("contents")
                if (contents != null) {
                    vapTagContents.putAll(contents)
                    for ((tag, content) in contents) {
                        val value = content["contentValue"]
                        val type = content["contentType"]
                        if (type == "image_url" && !value.isNullOrEmpty()) {
                            handleUrlImage(value, tag) {}
                        }
                    }
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Contents cannot be null", null)
                }
            }
            "getVapTagContent" -> {
                val tag = call.argument<String>("tag")
                if (tag != null) {
                    result.success(vapTagContents[tag])
                } else {
                    result.error("INVALID_ARGUMENT", "Tag cannot be null", null)
                }
            }
            "clearVapTagContents" -> {
                vapTagContents.clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun playFile(filePath: String?, id: String?, ticket: Int?, result: MethodChannel.Result?) {
        val playId = id ?: "req_${System.currentTimeMillis()}"
        val playTicket = ticket ?: ++ticketCounter

        // Idempotency: if this is a retry for the active clip that is already running, ignore it
        if (ticket != null && ticket == currentTicket && animView.isRunning()) {
            Log.i("VAP_TRACE", "playFile idempotent retry: id=$playId, ticket=$playTicket is already actively running, ignoring duplicate start")
            result?.success(null)
            return
        }

        currentTicket = playTicket
        currentPlayId = playId
        if (filePath == null) {
            Log.w("VAP_TRACE", "playFile REFUSED: id=$playId, ticket=$playTicket, reason=filePath is null")
            result?.error("INVALID_PATH", "File path cannot be null", null)
            return
        }
        val file = File(filePath)
        val exists = file.exists()
        val size = if (exists) file.length() else -1L
        Log.i("VAP_TRACE", "playFile request: id=$playId, ticket=$playTicket, path=$filePath, exists=$exists, size=$size, surfaceAvailable=${animView.isSurfaceAvailable}, isRunning=${animView.isRunning()}, visibility=${animView.visibility}")

        if (!exists || size <= 0) {
            Log.w("VAP_TRACE", "playFile REFUSED: id=$playId, ticket=$playTicket, reason=file does not exist or empty (size=$size)")
            result?.error("FILE_NOT_FOUND", "File does not exist or empty: $filePath", null)
            return
        }

        // Return immediately at request time to unblock Flutter caller
        result?.success(null)

        // Cancel any pending start from an earlier request
        cancelPendingStart()

        val startAction = Runnable {
            cancelPendingStart()
            if (isDisposed || playTicket < currentTicket) {
                Log.i("VAP_TRACE", "startGate: dropping superseded startAction for id=$playId, ticket=$playTicket < currentTicket=$currentTicket")
                return@Runnable
            }
            currentPlayId = playId
            hasCompleted = false
            cancelWatchdog()

            animView.visibility = View.VISIBLE
            animView.alpha = 0.001f

            if (animView.isSurfaceAvailable) {
                Log.i("VAP_TRACE", "startGate: starting play for id=$playId, ticket=$playTicket")
                animView.startPlay(file)
            } else {
                Log.i("VAP_TRACE", "startGate: waiting for surface for id=$playId, ticket=$playTicket")
                animView.prepareTextureView()
                animView.addOnSurfaceAvailableCallback {
                    mainHandler.post {
                        if (!isDisposed && currentPlayId == playId && playTicket >= currentTicket) {
                            animView.visibility = View.VISIBLE
                            animView.alpha = 0.001f
                            Log.i("VAP_TRACE", "startGate (deferred): surface ready, starting play for id=$playId, ticket=$playTicket")
                            animView.startPlay(file)
                        }
                    }
                }
            }
        }

        if (animView.isRunning()) {
            Log.i("VAP_TRACE", "startGate: clip is currently running, stopping active playback and waiting for release signal for id=$playId, ticket=$playTicket")
            animView.stopPlay()

            // Wait for the real release signal (dispatchVideoComplete)
            onReleaseCallback = {
                Log.i("VAP_TRACE", "startGate: real release signal fired for id=$playId, ticket=$playTicket")
                startAction.run()
            }

            // Upper bound timer (150ms): grace delay to avoid stalling if release signal is delayed
            val timeoutRunnable = Runnable {
                Log.w("VAP_TRACE", "startGate: upper-bound timer (150ms) reached, forcing start for id=$playId, ticket=$playTicket")
                val cb = onReleaseCallback
                cancelPendingStart()
                cb?.invoke()
            }
            pendingStartRunnable = timeoutRunnable
            mainHandler.postDelayed(timeoutRunnable, 150L)
        } else {
            startAction.run()
        }
    }

    private fun playAsset(assetName: String?, context: Context, result: MethodChannel.Result?) {
        if (assetName == null) { result?.error("INVALID_ASSET", "Asset name cannot be null", null); return }
        result?.success(null)
        hasCompleted = false
        cancelWatchdog()
        Log.i("VapView", "playAsset: $assetName")
        animView.visibility = View.VISIBLE
        animView.alpha = 1f
        if (animView.isSurfaceAvailable) {
            animView.startPlay(context.assets, assetName)
        } else {
            Log.i("VapView", "playAsset: surface not available yet, preparing texture view and waiting...")
            animView.prepareTextureView()
            animView.addOnSurfaceAvailableCallback {
                mainHandler.post {
                    if (!isDisposed) {
                        animView.visibility = View.VISIBLE
                        animView.alpha = 1f
                        animView.startPlay(context.assets, assetName)
                    }
                }
            }
        }
    }

    private fun applyScaleType(type: String?) {
        animView.setScaleType(
            when (type) {
                "centerCrop" -> ScaleType.CENTER_CROP
                "fitXY" -> ScaleType.FIT_XY
                else -> ScaleType.FIT_CENTER
            }
        )
    }

    private fun handleVapTagContent(content: String, contentType: String, tag: String, callback: (Bitmap?) -> Unit) {
        try {
            when (contentType) {
                "image_base64" -> handleBase64Image(content, tag, callback)
                "image_file" -> handleFileImage(content, tag, callback)
                "image_asset" -> handleAssetImage(content, tag, callback)
                "image_url" -> handleUrlImage(content, tag, callback)
                else -> callback(null)
            }
        } catch (e: Exception) {
            Log.e("VapView", "Error handling VAP tag content for tag '$tag': ${e.message}")
            callback(null)
        }
    }

    private fun handleBase64Image(content: String, tag: String, callback: (Bitmap?) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                var base64String = content
                when {
                    content.startsWith("data:image/") -> {
                        val commaIndex = content.indexOf(",")
                        if (commaIndex != -1) {
                            base64String = content.substring(commaIndex + 1)
                        }
                    }
                    content.startsWith("base64:") -> {
                        base64String = content.substring(7)
                    }
                }
                val byteArray = android.util.Base64.decode(base64String, android.util.Base64.DEFAULT)
                val bitmap = BitmapFactory.decodeByteArray(byteArray, 0, byteArray.size)
                val circular = if (bitmap != null) getCircularBitmap(bitmap) else null
                GlobalScope.launch(Dispatchers.Main) { callback(circular) }
            } catch (e: Exception) {
                Log.e("VapView", "Error decoding base64 image: ${e.message}")
                GlobalScope.launch(Dispatchers.Main) { callback(null) }
            }
        }
    }

    private fun handleFileImage(filePath: String, tag: String, callback: (Bitmap?) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                var fullPath = filePath
                when {
                    filePath.startsWith("/") -> fullPath = filePath
                    filePath.startsWith("file://") -> fullPath = filePath.substring(7)
                    else -> {
                        val context = frameLayout.context
                        val externalFile = File(context.getExternalFilesDir(null), filePath)
                        fullPath = if (externalFile.exists()) externalFile.absolutePath else File(context.filesDir, filePath).absolutePath
                    }
                }
                val file = File(fullPath)
                val bitmap = if (file.exists()) BitmapFactory.decodeFile(fullPath) else null
                val circular = if (bitmap != null) getCircularBitmap(bitmap) else null
                GlobalScope.launch(Dispatchers.Main) { callback(circular) }
            } catch (e: Exception) {
                Log.e("VapView", "Error loading file image: ${e.message}")
                GlobalScope.launch(Dispatchers.Main) { callback(null) }
            }
        }
    }

    private fun handleAssetImage(assetPath: String, tag: String, callback: (Bitmap?) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val inputStream = frameLayout.context.assets.open("flutter_assets/$assetPath")
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream.close()
                val circular = if (bitmap != null) getCircularBitmap(bitmap) else null
                GlobalScope.launch(Dispatchers.Main) { callback(circular) }
            } catch (e: Exception) {
                Log.e("VapView", "Error loading asset image: ${e.message}")
                GlobalScope.launch(Dispatchers.Main) { callback(null) }
            }
        }
    }

    private fun handleUrlImage(url: String, tag: String, callback: (Bitmap?) -> Unit) {
        val cached = bitmapCache.get(url)
        if (cached != null && !cached.isRecycled) {
            callback(cached)
            return
        }

        GlobalScope.launch(Dispatchers.IO) {
            var inputStream: InputStream? = null
            var conn: HttpURLConnection? = null
            try {
                var curUrl = url
                var redirects = 0
                while (redirects < 5) {
                    val u = URL(curUrl)
                    val c = u.openConnection() as HttpURLConnection
                    c.connectTimeout = 8000
                    c.readTimeout = 8000
                    c.instanceFollowRedirects = true
                    c.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android) HelloChat/1.0")
                    c.connect()
                    val code = c.responseCode
                    if (code in 300..399) {
                        val loc = c.getHeaderField("Location")
                        c.disconnect()
                        if (!loc.isNullOrEmpty()) {
                            curUrl = loc
                            redirects++
                            continue
                        }
                    }
                    conn = c
                    inputStream = c.inputStream
                    break
                }

                if (inputStream != null) {
                    val raw = BitmapFactory.decodeStream(inputStream)
                    if (raw != null) {
                        val circular = getCircularBitmap(raw)
                        bitmapCache.put(url, circular)
                        GlobalScope.launch(Dispatchers.Main) { callback(circular) }
                        return@launch
                    }
                }
                GlobalScope.launch(Dispatchers.Main) { callback(null) }
            } catch (e: Exception) {
                Log.e("VapView", "Error loading URL image for tag '$tag': ${e.message}")
                GlobalScope.launch(Dispatchers.Main) { callback(null) }
            } finally {
                runCatching { inputStream?.close() }
                runCatching { conn?.disconnect() }
            }
        }
    }

    private fun getCircularBitmap(src: Bitmap): Bitmap {
        val size = Math.min(src.width, src.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        if (src.width != size || src.height != size) {
            val matrix = Matrix()
            val dx = (size - src.width) / 2f
            val dy = (size - src.height) / 2f
            matrix.setTranslate(dx, dy)
            shader.setLocalMatrix(matrix)
        }
        paint.shader = shader
        val r = size / 2f
        canvas.drawCircle(r, r, r, paint)
        return output
    }

    companion object {
        private val bitmapCache = LruCache<String, Bitmap>(30)
        private var defaultAvatar: Bitmap? = null

        fun getDefaultAvatarBitmap(): Bitmap {
            defaultAvatar?.let { if (!it.isRecycled) return it }
            val size = 180
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = android.graphics.Color.parseColor("#381A5B")
            canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)

            val innerPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            innerPaint.color = android.graphics.Color.parseColor("#5A2A94")
            canvas.drawCircle(size / 2f, size / 2f, size * 0.44f, innerPaint)

            val headPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            headPaint.color = android.graphics.Color.parseColor("#00E5FF")
            canvas.drawCircle(size / 2f, size * 0.38f, size * 0.18f, headPaint)
            val rect = android.graphics.RectF(size * 0.22f, size * 0.60f, size * 0.78f, size * 1.05f)
            canvas.drawArc(rect, 180f, 180f, true, headPaint)

            defaultAvatar = bmp
            return bmp
        }
    }
}
