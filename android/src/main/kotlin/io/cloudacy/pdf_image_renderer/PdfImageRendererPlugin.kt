package io.cloudacy.pdf_image_renderer

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.pdf.LoadParams
import android.graphics.pdf.PdfRenderer
import android.graphics.pdf.PdfRenderer.Page
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.floor

/** PdfImageRendererPlugin */
class PdfImageRendererPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(LOG_TAG, "onAttachedToEngine - IN")
        if (pluginBinding != null) {
            Log.w(LOG_TAG, "onAttachedToEngine - already attached")
        }
        pluginBinding = flutterPluginBinding
        val messenger = pluginBinding?.binaryMessenger
        doOnAttachedToEngine(messenger!!)
        Log.d(LOG_TAG, "onAttachedToEngine - OUT")
    }

    companion object {
        const val LOG_TAG = "PdfImageRendererPlugin"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "openPDF" -> {
                enqueueTask(call, result, ::openPDF)
            }
            "closePDF" -> {
                enqueueTask(call, result, ::closePDF)
            }
            "openPDFPage" -> {
                enqueueTask(call, result, ::openPDFPage)
            }
            "closePDFPage" -> {
                enqueueTask(call, result, ::closePDFPage)
            }
            "renderPDFPage" -> {
                enqueueTask(call, result, ::renderPDFPageMethod)
            }
            "getPDFPageSize" -> {
                enqueueTask(call, result, ::getPDFPageSizeMethod)
            }
            "getPDFPageCount" -> {
                enqueueTask(call, result, ::getPDFPageCountMethod)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun enqueueTask(call: MethodCall, result: Result, task: (args: Map<String, Any?>) -> Any?) {
        Thread {
            val handler = Handler(Looper.getMainLooper())

            try {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?> ?: throw PdfImageRendererError.BadArguments()

                val taskResult = task(args)

                handler.post {
                    result.success(taskResult)
                }
            } catch (t: Throwable) {
                handler.post {
                    handlePdfError(t, result)
                }
            }
        }.start()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    }

    // Note: This may be called multiple times on app startup.
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(LOG_TAG, "onAttachedToActivity")
        doOnAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        Log.d(LOG_TAG, "onDetachedFromActivity")
        doOnDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(LOG_TAG, "onReattachedToActivityForConfigChanges")
        doOnAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(LOG_TAG, "onDetachedFromActivityForConfigChanges")
        doOnDetachedFromActivity()
    }

    private fun doOnAttachedToActivity(activityBinding: ActivityPluginBinding?) {
        Log.d(LOG_TAG, "doOnAttachedToActivity - IN")

        this.activityBinding = activityBinding

        Log.d(LOG_TAG, "doOnAttachedToActivity - OUT")
    }

    private fun doOnDetachedFromActivity() {
        Log.d(LOG_TAG, "doOnDetachedFromActivity - IN")

        activityBinding = null

        Log.d(LOG_TAG, "doOnDetachedFromActivity - OUT")
    }

    private fun doOnAttachedToEngine(messenger: BinaryMessenger) {
        Log.d(LOG_TAG, "doOnAttachedToEngine - IN")

        this.channel = MethodChannel(messenger, "pdf_image_renderer")
        this.channel.setMethodCallHandler(this)

        Log.d(LOG_TAG, "doOnAttachedToEngine - OUT")
    }

    private val openPFDs: MutableMap<Int, ParcelFileDescriptor> = ConcurrentHashMap()
    private val openPDFs: MutableMap<Int, PdfRenderer> = ConcurrentHashMap()
    private val openPDFPages: MutableMap<Int, Page> = ConcurrentHashMap()

    @Suppress("UNCHECKED_CAST")
    private fun <T> getArgument(args: Map<String, Any?>, arg: String): T {
        return args[arg] as? T ?: throw PdfImageRendererError.BadArgument(arg)
    }

    private fun getOpenPDF(args: Map<String, Any?>): PdfRenderer {
        val id = getArgument<Int>(args, "pdf")
        return openPDFs[id] ?: throw PdfImageRendererError.NotOpen(id)
    }

    private fun getOpenPDFPage(args: Map<String, Any?>): Page {
        val id = getArgument<Int>(args, "pdf")
        if (openPDFs[id] == null) throw PdfImageRendererError.NotOpen(id)
        return openPDFPages[id] ?: throw PdfImageRendererError.PageNotOpen(id)
    }

    private fun openPDF(args: Map<String, Any?>): Int {
        val path = getArgument<String>(args, "path")
        val password = args["password"] as? String

        val contentResolver = activityBinding!!.activity.contentResolver
        val pfd: ParcelFileDescriptor =
            contentResolver.openFileDescriptor(getURI(path), "r")!!
        val pfdFd = pfd.fd

        openPFDs[pfdFd] = pfd

        // Allow to open password-protected PDFs on Android 15.0+ devices.
        if (Build.VERSION.SDK_INT >= 35) {
            val loadParams = LoadParams.Builder()
            password?.let {
                loadParams.setPassword(it)
            }
            openPDFs[pfdFd] = PdfRenderer(pfd, loadParams.build())
        } else {
            openPDFs[pfdFd] = PdfRenderer(pfd)
        }

        return pfdFd
    }

    private fun closePDF(args: Map<String, Any?>): Int {
        val id = getArgument<Int>(args, "pdf")

        // Close the page of the pdf (if any is open)
        openPDFPages[id]?.close()
        openPDFPages.remove(id)

        // Close the PdfRenderer and the ParcelFileDescriptor.
        openPDFs[id]?.close()
        openPFDs[id]?.close()
        openPDFs.remove(id)
        openPFDs.remove(id)

        return id
    }

    private fun openPDFPage(args: Map<String, Any?>): Int {
        val id = getArgument<Int>(args, "pdf")
        val pageIndex = getArgument<Int>(args, "page")

        val pdf = openPDFs[id] ?: throw PdfImageRendererError.NotOpen(id)

        if (openPDFPages[id] != null) {
            throw PdfImageRendererError.PageAlreadyOpen(id)
        }

        openPDFPages[id] = pdf.openPage(pageIndex)

        return pageIndex
    }

    private fun closePDFPage(args: Map<String, Any?>): Int {
        val id = getArgument<Int>(args, "pdf")
        val pageIndex = getArgument<Int>(args, "page")

        val page = getOpenPDFPage(args)

        page.close()
        openPDFPages.remove(id)

        return pageIndex
    }

    private fun getPDFPageCountMethod(args: Map<String, Any?>): Int {
        return getOpenPDF(args).pageCount
    }

    private fun getPDFPageSizeMethod(args: Map<String, Any?>): Map<String, Int> {
        val page = getOpenPDFPage(args)

        return mapOf(
            "width" to page.width,
            "height" to page.height
        )
    }

    private fun renderPDFPageMethod(args: Map<String, Any?>): ByteArray {
        val page = getOpenPDFPage(args)

        val x = getArgument<Int>(args, "x")
        val y = getArgument<Int>(args, "y")
        val width = getArgument<Int>(args, "width")
        val height = getArgument<Int>(args, "height")
        val scale = getArgument<Double>(args, "scale")
        val background = args["background"] as? String

        val bitmap = renderPDFPage(page, x, y, width, height, scale.toFloat(), background)

        val byteStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteStream)

        return byteStream.toByteArray()
    }

    private fun renderPDFPage(
        page: Page,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        scale: Float,
        background: String?
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(
            floor(width * scale).toInt(),
            floor(height * scale).toInt(),
            Bitmap.Config.ARGB_8888
        )

        val parsedBackground = try {
            if (background != null)
                Color.parseColor(background)
            else
                Color.TRANSPARENT
        } catch (e: Exception) {
            Log.e("Parse", "Failed to parse $background. $e")
            Color.TRANSPARENT
        }
        bitmap.eraseColor(parsedBackground)

        val matrix = Matrix()
        matrix.postTranslate(-x.toFloat(), -y.toFloat())

        if (scale != 1.0f)
            matrix.postScale(scale, scale)

        page.render(
            bitmap,
            Rect(0, 0, floor(width * scale).toInt(), floor(height * scale).toInt()),
            matrix,
            Page.RENDER_MODE_FOR_DISPLAY
        )

        return bitmap
    }

    private fun getURI(uri: String): Uri {
        val parsed: Uri = Uri.parse(uri)
        val parsedScheme: String? = parsed.scheme
        return if ((parsedScheme == null) || parsedScheme.isEmpty()) {
            Uri.fromFile(File(uri))
        } else parsed
    }

    private fun handlePdfError(error: Throwable, result: Result) {
        when (error) {
            is PdfImageRendererError -> result.error("INVALID_ARGUMENTS", error.message, null)
            else -> result.error("EXECUTION_ERROR", error.message ?: error.toString(), null)
        }
    }
}

sealed class PdfImageRendererError(message: String) : Exception(message) {
    class BadArguments : PdfImageRendererError("Arguments have to be of type Map<String, Any?>.")
    class BadArgument(argument: String) :
        PdfImageRendererError("Invalid or missing \"$argument\" argument.")

    class NotOpen(pdfId: Int) : PdfImageRendererError("No PDF found for id $pdfId.")
    class PageNotOpen(pdfId: Int) : PdfImageRendererError("PDF $pdfId has no open page.")
    class PageAlreadyOpen(pdfId: Int) :
        PdfImageRendererError("PDF $pdfId already has an open page.")
}
