package io.cloudacy.packages.pdf_image_renderer

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.graphics.pdf.PdfRenderer.Page
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.floor

/** PdfImageRendererPlugin */
class PdfImageRendererPlugin: FlutterPlugin, MethodCallHandler {
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val channel = MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "pdf_image_renderer")
    channel.setMethodCallHandler(PdfImageRendererPlugin())
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "pdf_image_renderer")
      channel.setMethodCallHandler(PdfImageRendererPlugin())
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "openPDF" -> {
        openPDF(call, result)
      }
      "closePDF" -> {
        closePDF(call, result)
      }
      "openPDFPage" -> {
        openPDFPage(call, result)
      }
      "closePDFPage" -> {
        closePDFPage(call, result)
      }
      "renderPDFPage" -> {
        renderPDFPageMethod(call, result)
      }
      "getPDFPageSize" -> {
        getPDFPageSizeMethod(call, result)
      }
      "getPDFPageCount" -> {
        getPDFPageCountMethod(call, result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }

  private val openPFDs: MutableMap<Int, ParcelFileDescriptor> = mutableMapOf()
  private val openPDFs: MutableMap<Int, PdfRenderer> = mutableMapOf()
  private val openPDFPages: MutableMap<Int, MutableMap<Int, Page>> = mutableMapOf()

  private fun openPDF(@NonNull call: MethodCall, @NonNull result: Result) {
    val path = call.argument<String>("path")
    if (path == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"path\" argument.", null)
      return
    }

    try {
      val pfd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
      openPFDs[pfd.fd] = pfd
      openPDFs[pfd.fd] = PdfRenderer(pfd)
      result.success(pfd.fd)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun closePDF(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = call.argument<Int>("pdf")
    if (id == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"id\" argument.", null)
      return
    }

    if (openPDFPages[id] != null) {
      for (page in openPDFPages[id]!!) {
        page.value.close()
      }
      openPDFPages.remove(id)
    }

    try {
      if (openPDFs.containsKey(id)) {
        openPDFs[id]!!.close()
        openPFDs[id]!!.close()
        openPDFs.remove(id)
        openPFDs.remove(id)
      }
      result.success(id)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun openPDFPage(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = call.argument<Int>("pdf")
    if (id == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"id\" argument.", null)
      return
    }

    val page = call.argument<Int>("page")
    if (page == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"page\" argument.", null)
      return
    }

    if (openPDFs[id] == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    if (openPDFPages[id] != null && openPDFPages[id]!![page] != null) {
      result.error("INVALID_ARGUMENTS", "Page $page for PDF $id is already open.", null)
      return
    }

    try {
      if (openPDFPages[id] == null) {
        openPDFPages[id] = mutableMapOf()
      }

      openPDFPages[id]!![page] = openPDFs[id]!!.openPage(page)

      result.success(page)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun closePDFPage(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = call.argument<Int>("pdf")
    if (id == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"id\" argument.", null)
      return
    }

    val page = call.argument<Int>("page")
    if (page == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"page\" argument.", null)
      return
    }

    if (openPDFs[id] == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    if (openPDFPages[id] != null && openPDFPages[id]!![page] == null) {
      result.error("INVALID_ARGUMENTS", "Page $page for PDF $id is not open.", null)
      return
    }

    try {
      openPDFPages[id]!![page]!!.close()
      openPDFPages[id]!!.remove(page)

      result.success(page)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun getPDFPageCountMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = call.argument<Int>("pdf")
    if (id == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"id\" argument.", null)
      return
    }

    if (openPDFs[id] == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    try {
      result.success(openPDFs[id]!!.pageCount)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun getPDFPageSizeMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = call.argument<Int>("pdf")
    if (id == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"id\" argument.", null)
      return
    }

    val page = call.argument<Int>("page")
    if (page == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing \"page\" argument.", null)
      return
    }

    if (openPDFs[id] == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    if (openPDFPages[id] != null && openPDFPages[id]!![page] == null) {
      result.error("INVALID_ARGUMENTS", "Page $page for PDF $id is not open.", null)
      return
    }

    try {
      val pdfPage = openPDFPages[id]!![page]!!
      result.success(mapOf(
        "width" to pdfPage.width,
        "height" to pdfPage.height
      ))
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun renderPDFPageMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    Thread {
      val handler = Handler(Looper.getMainLooper())

      val id = call.argument<Int>("pdf")
      if (id == null) {
        result.error("INVALID_ARGUMENTS", "Invalid or missing \"id\" argument.", null)
        return@Thread
      }

      val page = call.argument<Int>("page")
      if (page == null) {
        result.error("INVALID_ARGUMENTS", "Invalid or missing \"page\" argument.", null)
        return@Thread
      }

      if (openPDFs[id] == null) {
        result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
        return@Thread
      }

      if (openPDFPages[id] != null && openPDFPages[id]!![page] == null) {
        result.error("INVALID_ARGUMENTS", "Page $page for PDF $id is not open.", null)
        return@Thread
      }

      val x = call.argument<Int>("x")
      val y = call.argument<Int>("y")
      val width = call.argument<Int>("width")
      val height = call.argument<Int>("height")
      val scale = call.argument<Double>("scale")
      val background = call.argument<String>("background")
      if (x == null || y == null || width == null || height == null || scale == null) {
        handler.post {
          result.error("INVALID_ARGUMENTS", "Invalid or missing arguments.", null)
        }
        return@Thread
      }

      try {
        val bitmap = renderPDFPage(openPDFPages[id]!![page]!!, x, y, width, height, scale.toFloat(), background)

        val byteStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteStream)
        handler.post {
          result.success(byteStream.toByteArray())
        }
      } catch (e: Exception) {
        handler.post {
          result.error("EXECUTION_ERROR", e.message, null)
        }
      }
    }.start()
  }

  private fun renderPDFPage(page: Page, x: Int, y: Int, width: Int, height: Int, scale: Float, background: String?): Bitmap {
    val bitmap = Bitmap.createBitmap(floor(width * scale).toInt(), floor(height * scale).toInt(), Bitmap.Config.ARGB_8888)
    val parsedBackground = try {
      if (background != null)
        Color.parseColor(background)
      else
        Color.TRANSPARENT
    } catch (e: Exception) {
      print("failed to parse $background. $e")
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
}
