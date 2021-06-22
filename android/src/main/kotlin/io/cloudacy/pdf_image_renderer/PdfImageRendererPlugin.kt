package io.cloudacy.pdf_image_renderer

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.graphics.pdf.PdfRenderer.Page
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
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
  private val openPDFPages: MutableMap<Int, Page> = mutableMapOf()

  private fun <T> getArgument(@NonNull call: MethodCall, @NonNull result: Result, arg: String, optional: Boolean = false): T? {
    val value = call.argument<T>(arg)
    if (value == null && !optional) result.error("INVALID_ARGUMENTS", "Invalid or missing \"$arg\" argument.", null)
    return value
  }

  private fun openPDF(@NonNull call: MethodCall, @NonNull result: Result) {
    val path = getArgument<String>(call, result, "path") ?: return

    Thread {
      val handler = Handler(Looper.getMainLooper())

      try {
        val pfd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        openPFDs[pfd.fd] = pfd
        openPDFs[pfd.fd] = PdfRenderer(pfd)

        handler.post {
          result.success(pfd.fd)
        }
      } catch (e: Exception) {
        handler.post {
          result.error("EXECUTION_ERROR", e.message, null)
        }
      }
    }.start()
  }

  private fun closePDF(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = getArgument<Int>(call, result, "pdf") ?: return

    // Close the page of the pdf (if any is open)
    openPDFPages[id]?.close()
    openPDFPages.remove(id)

    try {
      // Close the PdfRenderer and the ParcelFileDescriptor.
      openPDFs[id]?.close()
      openPFDs[id]?.close()
      openPDFs.remove(id)
      openPFDs.remove(id)

      result.success(id)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun openPDFPage(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = getArgument<Int>(call, result, "pdf") ?: return

    val pageIndex = getArgument<Int>(call, result, "page") ?: return

    val pdf = openPDFs[id]
    if (pdf == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    if (openPDFPages[id] != null) {
      result.error("INVALID_ARGUMENTS", "PDF $id already has an open page.", null)
      return
    }

    Thread {
      val handler = Handler(Looper.getMainLooper())

      try {
        openPDFPages[id] = pdf.openPage(pageIndex)

        handler.post {
          result.success(pageIndex)
        }
      } catch (e: Exception) {
        handler.post {
          result.error("EXECUTION_ERROR", e.message, null)
        }
      }
    }.start()
  }

  private fun closePDFPage(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = getArgument<Int>(call, result, "pdf") ?: return
    val pageIndex = getArgument<Int>(call, result, "page") ?: return

    if (openPDFs[id] == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    val page = openPDFPages[id]
    if (page == null) {
      result.error("INVALID_ARGUMENTS", "PDF $id has no open page.", null)
      return
    }

    try {
      page.close()
      openPDFPages.remove(id)

      result.success(pageIndex)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun getPDFPageCountMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = getArgument<Int>(call, result, "pdf") ?: return

    val pdf = openPDFs[id]
    if (pdf == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    try {
      result.success(pdf.pageCount)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun getPDFPageSizeMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = getArgument<Int>(call, result, "pdf") ?: return

    if (openPDFs[id] == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    val page = openPDFPages[id]
    if (page == null) {
      result.error("INVALID_ARGUMENTS", "PDF $id has no open page.", null)
      return
    }

    try {
      result.success(mapOf(
        "width" to page.width,
        "height" to page.height
      ))
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun renderPDFPageMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = getArgument<Int>(call, result, "pdf") ?: return

    val pdf = openPDFs[id]
    if (pdf == null) {
      result.error("INVALID_ARGUMENTS", "No PDF found for id $id.", null)
      return
    }

    val page = openPDFPages[id]
    if (page == null) {
      result.error("INVALID_ARGUMENTS", "Page $page for PDF $id is not open.", null)
      return
    }

    val x = getArgument<Int>(call, result, "x") ?: return
    val y = getArgument<Int>(call, result, "y") ?: return
    val width = getArgument<Int>(call, result, "width") ?: return
    val height = getArgument<Int>(call, result, "height") ?: return
    val scale = getArgument<Double>(call, result, "scale") ?: return
    val background = getArgument<String>(call, result, "background", true)

    Thread {
      val handler = Handler(Looper.getMainLooper())

      try {
        val bitmap = renderPDFPage(page, x, y, width, height, scale.toFloat(), background)

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
}
