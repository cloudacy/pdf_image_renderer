import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class PdfImageRenderer {
  static const MethodChannel _channel = const MethodChannel('pdf_image_renderer');

  static Future<Uint8List> renderPDF(String path) async {
    final Uint8List image = await _channel.invokeMethod('renderPDFPage', {
      'path': path,
      'page': 0,
      'x': 0,
      'y': 0,
      'width': 100,
      'height': 100,
      'scale': 1,
      'background': '#ffffffff',
    });
    return image;
  }
}
