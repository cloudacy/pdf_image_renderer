import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PdfImageRendererPageSize {
  final int width;
  final int height;

  const PdfImageRendererPageSize({@required this.width, @required this.height});
}

class PdfImageRenderer {
  static const MethodChannel _channel = const MethodChannel('pdf_image_renderer');

  /// Returns the number of pages for the PDF located at given path.
  static Future<int> getPDFPageCount({
    @required String path,
  }) async {
    final int count = await _channel.invokeMethod('getPDFPageCount', {
      'path': path,
    });
    return count;
  }

  /// Returns an instance of PdfImageRendererPageSize, holding the width and height in points
  /// of the page at given index of the PDF located at given path.
  static Future<PdfImageRendererPageSize> getPDFPageSize({
    @required String path,
    @required int page,
  }) async {
    final Map<String, int> size = await _channel.invokeMapMethod('getPDFPageSize', {
      'path': path,
      'page': page,
    });
    return PdfImageRendererPageSize(
      width: size['width'],
      height: size['height'],
    );
  }

  static Future<Uint8List> renderPDFPage({
    @required String path,
    @required int page,
    @required int x,
    @required int y,
    @required int width,
    @required int height,
    @required int scale,
    @required String background,
  }) async {
    final Uint8List image = await _channel.invokeMethod('renderPDFPage', {
      'path': path,
      'page': page,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'scale': scale,
      'background': background,
    });
    return image;
  }
}
