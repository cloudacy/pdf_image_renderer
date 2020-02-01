import 'dart:async';

import 'package:flutter/services.dart';

class PdfImageRenderer {
  static const MethodChannel _channel = const MethodChannel('pdf_image_renderer');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
