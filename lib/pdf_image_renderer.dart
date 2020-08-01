import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

void printTime(String message) {
  message = "[${DateTime.now()}]: $message";
  debugPrintSynchronously(message);
}

class PdfImageRendererPdf {
  String path;
  int id;
  Set<int> pages;

  int pageCount;
  Map<int, PdfImageRendererPageSize> pageSizes;

  PdfImageRendererPdf({@required this.path});

  Future<int> open() async {
    if (id != null) return id;

    printTime("Open PDF $path");

    id = await PdfImageRenderer.openPdf(path: path);
    pages = Set();

    printTime("PDF opened.");

    return id;
  }

  Future<bool> close() async {
    if (id == null) return false;

    await PdfImageRenderer.closePdf(pdf: id);

    id = null;
    pages = Set();
    pageCount = null;
    pageSizes = null;

    return true;
  }

  Future<int> openPage({@required int pageIndex}) async {
    if (pages.contains(pageIndex)) return pageIndex;

    await PdfImageRenderer.openPdfPage(pdf: id, page: pageIndex);

    pages.add(pageIndex);

    return pageIndex;
  }

  Future<int> getPageCount() async {
    if (pageCount != null) return pageCount;

    pageCount = await PdfImageRenderer.getPDFPageCount(pdf: id);

    return pageCount;
  }

  Future<PdfImageRendererPageSize> getPageSize({@required int pageIndex}) async {
    if (pageSizes == null) pageSizes = {};

    if (pageSizes.containsKey(pageIndex)) return pageSizes[pageIndex];

    if (!pages.contains(pageIndex)) await openPage(pageIndex: pageIndex);

    pageSizes[pageIndex] = await PdfImageRenderer.getPDFPageSize(pdf: id, page: pageIndex);

    return pageSizes[pageIndex];
  }

  Future<Uint8List> renderPage({
    int pageIndex = 0,
    int x,
    int y,
    int width,
    int height,
    double scale,
    Color background,
  }) async {
    if (!pages.contains(pageIndex)) await openPage(pageIndex: pageIndex);

    Uint8List bytes = await PdfImageRenderer.renderPDFPage(
      pdf: id,
      page: pageIndex,
      x: x,
      y: y,
      width: width,
      height: height,
      scale: scale,
      background: background,
    );

    return bytes;
  }
}

class PdfImageRendererPageSize {
  final int width;
  final int height;

  const PdfImageRendererPageSize({@required this.width, @required this.height});
}

class PdfImageRenderer {
  static const MethodChannel _channel = const MethodChannel('pdf_image_renderer');

  static Future<int> openPdf({
    @required String path,
  }) async {
    final int pdf = await _channel.invokeMethod('openPDF', {
      'path': path,
    });
    return pdf;
  }

  static Future<int> closePdf({
    @required int pdf,
  }) async {
    final int id = await _channel.invokeMethod('closePDF', {
      'pdf': pdf,
    });
    return id;
  }

  static Future<int> openPdfPage({
    @required int pdf,
    @required int page,
  }) async {
    final int index = await _channel.invokeMethod('openPDFPage', {
      'pdf': pdf,
      'page': page,
    });
    return index;
  }

  static Future<int> closePdfPage({
    @required int pdf,
    @required int page,
  }) async {
    final int index = await _channel.invokeMethod('closePDFPage', {
      'pdf': pdf,
      'page': page,
    });
    return index;
  }

  /// Returns the number of pages for the PDF located at given path.
  static Future<int> getPDFPageCount({
    @required int pdf,
  }) async {
    final int count = await _channel.invokeMethod('getPDFPageCount', {
      'pdf': pdf,
    });
    return count;
  }

  /// Returns an instance of PdfImageRendererPageSize, holding the width and height in points
  /// of the page at given index of the PDF located at given path.
  static Future<PdfImageRendererPageSize> getPDFPageSize({
    @required int pdf,
    @required int page,
  }) async {
    final Map<String, int> size = await _channel.invokeMapMethod('getPDFPageSize', {
      'pdf': pdf,
      'page': page,
    });
    return PdfImageRendererPageSize(
      width: size['width'],
      height: size['height'],
    );
  }

  static Future<Uint8List> renderPDFPage({
    @required int pdf,
    @required int page,
    int x,
    int y,
    int width,
    int height,
    double scale,
    Color background = const Color(0xFFFFFFFF),
  }) async {
    PdfImageRendererPageSize size;

    if (width == null || height == null) {
      size = await getPDFPageSize(pdf: pdf, page: page);

      if (width == null) width = size.width;
      if (height == null) height = size.height;
    }

    final Uint8List image = await _channel.invokeMethod('renderPDFPage', {
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
