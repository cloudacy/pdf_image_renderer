import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// PDF according to a [PdfImageRenderer] to convert it to a bitmap.
class PdfImageRendererPdf {
  final String _path;
  int? _id;
  Set<int>? _pages;

  int? _pageCount;
  Map<int, PdfImageRendererPageSize>? _pageSizes;

  /// Construct a new renderer PDF by a given [path].
  PdfImageRendererPdf({required String path}) : _path = path;

  /// Open the PDF by the path this [PdfImageRendererPdf] was initialized with.
  ///
  /// Must be closed with the [close] method to free up memory.
  Future<int> open() async {
    if (_id != null) return _id!;

    _id = await PdfImageRenderer.openPdf(path: _path);
    _pages = {};

    return _id!;
  }

  /// Closes the PDF.
  ///
  /// Must be opened with the [open] method before.
  Future<bool> close() async {
    if (_id == null) return false;

    await PdfImageRenderer.closePdf(pdf: _id!);

    _id = null;
    _pages = {};
    _pageCount = null;
    _pageSizes = null;

    return true;
  }

  /// Open a PDF page with given index.
  /// Index is starting with 0.
  /// PDF must be opened with the `open` method before.
  Future<int> openPage({required int pageIndex}) async {
    if (_id == null || _pages == null) {
      throw StateError('PDF is not opened yet!');
    }

    if (_pages!.contains(pageIndex)) return pageIndex;

    await PdfImageRenderer.openPdfPage(pdf: _id!, page: pageIndex);

    _pages!.add(pageIndex);

    return pageIndex;
  }

  /// Returns the number of pages of the PDF.
  /// PDF must be opened with the `open` method before.
  Future<int> getPageCount() async {
    if (_id == null) throw StateError('PDF is not opened yet!');
    if (_pageCount != null) return _pageCount!;

    _pageCount = await PdfImageRenderer.getPDFPageCount(pdf: _id!);

    return _pageCount!;
  }

  /// Gets the [PdfImageRendererPageSize] by the given [pageIndex].
  ///
  /// If the size was already fetched before, it will be returned from memory.
  Future<PdfImageRendererPageSize> getPageSize({required int pageIndex}) async {
    if (_id == null || _pages == null) {
      throw StateError('PDF is not opened yet!');
    }

    if (_pageSizes == null) _pageSizes = {};

    if (_pageSizes!.containsKey(pageIndex)) return _pageSizes![pageIndex]!;

    if (!_pages!.contains(pageIndex)) await openPage(pageIndex: pageIndex);

    _pageSizes![pageIndex] =
        await PdfImageRenderer.getPDFPageSize(pdf: _id!, page: pageIndex);

    return _pageSizes![pageIndex]!;
  }

  /// Converts a page with the given [pageIndex] to a bitmap.
  ///
  /// Optionally crop the output image to a given [x] and [y] coordinate with a given [width], [height].
  ///
  /// With the [scale] argument you can control the output resolution.
  /// Default scale is `1` which means that the output image has exactly the size of the PDF.
  ///
  /// Optionally set the [background] color which will be used instead of transparency.
  Future<Uint8List?> renderPage({
    int pageIndex = 0,
    int? x,
    int? y,
    int? width,
    int? height,
    double? scale,
    Color background = const Color(0xFFFFFFFF),
  }) async {
    if (_id == null || _pages == null) {
      throw StateError('PDF is not opened yet!');
    }

    if (!_pages!.contains(pageIndex)) await openPage(pageIndex: pageIndex);

    var bytes = await PdfImageRenderer.renderPDFPage(
      pdf: _id!,
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

/// Holds the [width] and [height] of a [PdfImageRendererPdf].
class PdfImageRendererPageSize {
  /// Width of the page.
  final int width;

  /// Height of the page.
  final int height;

  /// Construct a size object by the given [width] and [height].
  const PdfImageRendererPageSize({required this.width, required this.height});
}

/// Renderer for converting PDFs to bitmaps.
class PdfImageRenderer {
  static const MethodChannel _channel = MethodChannel('pdf_image_renderer');

  /// Open a PDF from the given [path].
  static Future<int?> openPdf({
    required String path,
  }) async {
    final pdf = await _channel.invokeMethod<int>('openPDF', {
      'path': path,
    });
    return pdf;
  }

  /// Close a PDF by the given [pdf] identifier.
  ///
  /// The identifier comes from the [openPdf] method.
  static Future<int?> closePdf({
    required int pdf,
  }) async {
    final id = await _channel.invokeMethod<int>('closePDF', {
      'pdf': pdf,
    });
    return id;
  }

  /// Open a PDF page by the given [pdf] identifier and the given [page] index.
  ///
  /// Index is starting with `0`.
  static Future<int?> openPdfPage({
    required int pdf,
    required int page,
  }) async {
    final index = await _channel.invokeMethod<int>('openPDFPage', {
      'pdf': pdf,
      'page': page,
    });
    return index;
  }

  /// Close a PDF page by the given [pdf] identifier and the given [page] index.
  ///
  /// Index is starting with `0`.
  static Future<int?> closePdfPage({
    required int pdf,
    required int page,
  }) async {
    final index = await _channel.invokeMethod<int>('closePDFPage', {
      'pdf': pdf,
      'page': page,
    });
    return index;
  }

  /// Returns the number of pages for the PDF located at given path.
  static Future<int?> getPDFPageCount({
    required int pdf,
  }) async {
    final count = await _channel.invokeMethod<int>('getPDFPageCount', {
      'pdf': pdf,
    });
    return count;
  }

  /// Returns an instance of [PdfImageRendererPageSize], holding the width and height in points
  /// of the page at given index of the PDF located at given path.
  static Future<PdfImageRendererPageSize> getPDFPageSize({
    required int pdf,
    required int page,
  }) async {
    final size =
        (await _channel.invokeMapMethod<String, int>('getPDFPageSize', {
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
  static Future<Uint8List?> renderPDFPage({
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
      size = await getPDFPageSize(pdf: pdf, page: page);

      if (width == null) width = size.width;
      if (height == null) height = size.height;
    }

    final image = await _channel.invokeMethod<Uint8List>('renderPDFPage', {
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
