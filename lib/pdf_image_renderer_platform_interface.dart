import 'dart:typed_data';
import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pdf_image_renderer.dart' show PdfImageRendererPageSize;
import 'pdf_image_renderer_method_channel.dart';

abstract class PdfImageRendererPlatform extends PlatformInterface {
  /// Constructs a PdfImageRendererPlatform.
  PdfImageRendererPlatform() : super(token: _token);

  static final Object _token = Object();

  static PdfImageRendererPlatform _instance = MethodChannelPdfImageRenderer();

  /// The default instance of [PdfImageRendererPlatform] to use.
  ///
  /// Defaults to [MethodChannelPdfImageRenderer].
  static PdfImageRendererPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PdfImageRendererPlatform] when
  /// they register themselves.
  static set instance(PdfImageRendererPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int?> openPdf({
    required String path,
    String? password,
  }) async {
    throw UnimplementedError('openPdf() has not been implemented.');
  }

  Future<int?> closePdf({
    required int pdf,
  }) async {
    throw UnimplementedError('closePdf() has not been implemented.');
  }

  /// Open a PDF page by the given [pdf] identifier and the given [page] index.
  ///
  /// Index is starting with `0`.
  Future<int?> openPdfPage({
    required int pdf,
    required int page,
  }) async {
    throw UnimplementedError('openPdfPage() has not been implemented.');
  }

  /// Close a PDF page by the given [pdf] identifier and the given [page] index.
  ///
  /// Index is starting with `0`.
  Future<int?> closePdfPage({
    required int pdf,
    required int page,
  }) async {
    throw UnimplementedError('closePdfPage() has not been implemented.');
  }

  /// Returns the number of pages for the PDF located at given path.
  Future<int?> getPdfPageCount({
    required int pdf,
  }) async {
    throw UnimplementedError('getPdfPageCount() has not been implemented.');
  }

  /// Returns an instance of [PdfImageRendererPageSize], holding the width and height in points
  /// of the page at given index of the PDF located at given path.
  Future<PdfImageRendererPageSize> getPdfPageSize({
    required int pdf,
    required int page,
  }) async {
    throw UnimplementedError('getPDFPageSize() has not been implemented.');
  }

  /// Converts a given [page] from a given [pdf] to a bitmap.
  ///
  /// Optionally crop the output image to a given [x] and [y] coordinate with a given [width], [height].
  ///
  /// With the [scale] argument you can control the output resolution.
  /// Default scale is `1` which means that the output image has exactly the size of the PDF.
  ///
  /// Optionally set the [background] color which will be used instead of transparency.
  Future<Uint8List?> renderPdfPage({
    required int pdf,
    required int page,
    int? x,
    int? y,
    int? width,
    int? height,
    double? scale,
    Color background = const Color(0xFFFFFFFF),
  }) async {
    throw UnimplementedError('renderPDFPage() has not been implemented.');
  }
}
