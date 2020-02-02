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
    if (call.method == "renderPDFPage") {
      renderPDFPageMethod(call, result)
    } else if (call.method == "getPDFPageSize") {
      getPDFPageSizeMethod(call, result)
    } else if (call.method == "getPDFPageCount") {
      getPDFPageCountMethod(call, result)
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }

  private fun getPDFPageCountMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    val path = call.argument<String>("path")
    if (path == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing arguments.", null)
      return
    }

    val file = File(path)
    try {
      val count = getPDFPageCount(file)
      result.success(count)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun getPDFPageCount(file: File): Int {
    val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    fd.use {
      val renderer = PdfRenderer(fd)
      renderer.use {
        return renderer.pageCount
      }
    }
  }

  private fun getPDFPageSizeMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    val path = call.argument<String>("path")
    val page = call.argument<Int>("page")
    if (path == null || page == null) {
      result.error("INVALID_ARGUMENTS", "Invalid or missing arguments.", null)
      return
    }

    val file = File(path)
    try {
      val pageSize = getPDFPageSize(file, page)
      result.success(pageSize)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", e.message, null)
    }
  }

  private fun getPDFPageSize(file: File, pageIndex: Int): Map<String, Int> {
    val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    fd.use {
      val renderer = PdfRenderer(fd)
      renderer.use {
        val page = renderer.openPage(pageIndex)
        page.use {
          return mapOf(
            "width" to page.width,
            "height" to page.height
          )
        }
      }
    }
  }

  private fun renderPDFPageMethod(@NonNull call: MethodCall, @NonNull result: Result) {
    Thread {
      val handler = Handler(Looper.getMainLooper())
      val path = call.argument<String>("path")
      val page = call.argument<Int>("page")
      val x = call.argument<Int>("x")
      val y = call.argument<Int>("y")
      val width = call.argument<Int>("width")
      val height = call.argument<Int>("height")
      val scale = call.argument<Int>("scale")
      val background = call.argument<String>("background")
      if (path == null || page == null || x == null || y == null || width == null || height == null || scale == null) {
        handler.post {
          result.error("INVALID_ARGUMENTS", "Invalid or missing arguments.", null)
        }
        return@Thread
      }

      val file = File(path)
      try {
        val bitmap = renderPDFPage(file, page, x, y, width, height, scale, background)

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

  private fun renderPDFPage(file: File, pageIndex: Int, x: Int, y: Int, width: Int, height: Int, scale: Int, background: String?): Bitmap {
    val bitmap = Bitmap.createBitmap(width * scale, height * scale, Bitmap.Config.ARGB_8888)
    val parsedBackground = try {
      if (background == null)
        Color.parseColor(background)
      else
        Color.TRANSPARENT
    } catch (e: Exception) {
      Color.TRANSPARENT
    }
    bitmap.eraseColor(parsedBackground)

    val matrix = Matrix()
    println("$x, $y, $width, $height, $scale")
    matrix.postTranslate(-x.toFloat(), -y.toFloat())
    if (scale != 1)
      matrix.postScale(scale.toFloat(), scale.toFloat())

    val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    fd.use {
      val renderer = PdfRenderer(fd)
      renderer.use {
        val page = renderer.openPage(pageIndex)
        page.use {
          page.render(
            bitmap,
            Rect(0, 0, width * scale, height * scale),
            matrix,
            Page.RENDER_MODE_FOR_DISPLAY
          )
        }
      }
    }

    return bitmap
  }
}
