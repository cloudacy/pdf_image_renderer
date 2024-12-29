import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pdf_image_renderer.dart' show PdfImageRendererPageSize;
import 'pdf_image_renderer_platform_interface.dart';

/// An implementation of [PdfImageRendererPlatform] that uses method channels.
class MethodChannelPdfImageRenderer extends PdfImageRendererPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pdf_image_renderer');

  /// Open a PDF from the given [path].
  @override
  Future<int?> openPdf({
    required String path,
    String? password,
  }) async {
    final pdf = await methodChannel.invokeMethod<int>('openPDF', {
      'path': path,
      if (password case final password?) 'password': password,
    });
    return pdf;
  }

  /// Close a PDF by the given [pdf] identifier.
  ///
  /// The identifier comes from the [openPdf] method.
  @override
  Future<int?> closePdf({
    required int pdf,
  }) async {
    final id = await methodChannel.invokeMethod<int>('closePDF', {
      'pdf': pdf,
    });
    return id;
  }

  /// Open a PDF page by the given [pdf] identifier and the given [page] index.
  ///
  /// Index is starting with `0`.
  @override
  Future<int?> openPdfPage({
    required int pdf,
    required int page,
  }) async {
    final index = await methodChannel.invokeMethod<int>('openPDFPage', {
      'pdf': pdf,
      'page': page,
    });
    return index;
  }

  /// Close a PDF page by the given [pdf] identifier and the given [page] index.
  ///
  /// Index is starting with `0`.
  @override
  Future<int?> closePdfPage({
    required int pdf,
    required int page,
  }) async {
    if (Platform.isAndroid) {
      final index = await methodChannel.invokeMethod<int>('closePDFPage', {
        'pdf': pdf,
        'page': page,
      });
      return index;
    } else {
      return page;
    }
  }

  /// Returns the number of pages for the PDF located at given path.
  @override
  Future<int?> getPdfPageCount({
    required int pdf,
  }) async {
    final count = await methodChannel.invokeMethod<int>('getPDFPageCount', {
      'pdf': pdf,
    });
    return count;
  }

  /// Returns an instance of [PdfImageRendererPageSize], holding the width and height in points
  /// of the page at given index of the PDF located at given path.
  @override
  Future<PdfImageRendererPageSize> getPdfPageSize({
    required int pdf,
    required int page,
  }) async {
    final size = (await methodChannel.invokeMapMethod<String, int>('getPDFPageSize', {
      'pdf': pdf,
      'page': page,
    }))!;

    return PdfImageRendererPageSize(
      width: size['width']!,
      height: size['height']!,
    );
  }

  /// Converts a given [page] from a given [pdf] to a bitmap.
  ///
  /// Optionally crop the output image to a given [x] and [y] coordinate with a given [width], [height].
  ///
  /// With the [scale] argument you can control the output resolution.
  /// Default scale is `1` which means that the output image has exactly the size of the PDF.
  ///
  /// Optionally set the [background] color which will be used instead of transparency.
  @override
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
    PdfImageRendererPageSize size;

    if (width == null || height == null) {
      size = await getPdfPageSize(pdf: pdf, page: page);

      width ??= size.width;
      height ??= size.height;
    }

    final image = await methodChannel.invokeMethod<Uint8List>('renderPDFPage', {
      'pdf': pdf,
      'page': page,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'scale': scale,
      'background': '#${background.value.toRadixString(16)}',
    });
    return image;
  }
}
