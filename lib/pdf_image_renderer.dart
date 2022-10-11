import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// PDF according to a [PdfImageRenderer] to convert it to a bitmap.
class PdfImageRendererPdf {
  /// Path to the PDF file.
  final String _path;

  /// Platform PDF id. null, if PDF is not open.
  int? _id;

  /// Open pages.
  final _pages = <int>{};

  /// Page count cache.
  int? _pageCount;

  /// Page sizes cache.
  final _pageSizes = <int, PdfImageRendererPageSize>{};

  /// Construct a new renderer PDF by a given [path].
  PdfImageRendererPdf({
    required String path,
  }) : _path = path;

  /// Open the PDF by the path this [PdfImageRendererPdf] was initialized with.
  ///
  /// Must be closed with the [close] method to free up memory.
  Future<void> open() async {
    if (_id != null) return;

    _id = await PdfImageRenderer.openPdf(path: _path);
  }

  /// Closes the PDF.
  ///
  /// Must be opened with the [open] method before.
  Future<void> close() async {
    if (_id == null) throw StateError('PDF is not open!');

    // Close all open PDF pages.
    final pages = [..._pages];
    for (final page in pages) {
      await closePage(pageIndex: page);
    }

    await PdfImageRenderer.closePdf(pdf: _id!);

    _id = null;
    _pages.clear();
    _pageCount = null;
    _pageSizes.clear();
  }

  /// Open a PDF page with given index.
  /// Index is starting with 0.
  /// PDF must be opened with the `open` method before.
  Future<void> openPage({required int pageIndex}) async {
    if (_id == null) throw StateError('Please open the PDF first!');

    if (_pages.contains(pageIndex)) return;

    if (Platform.isAndroid && _pages.isNotEmpty) {
      throw StateError(
          'The native Android PDF renderer only allows one open page for each PdfImageRendererPdf instance. Please close the open page first.');
    }

    await PdfImageRenderer.openPdfPage(pdf: _id!, page: pageIndex);

    _pages.add(pageIndex);
  }

  /// Close an open PDF page with given index.
  /// Index is starting with 0.
  /// PDF and PDF page must be opened before, by using the `open` and `openPage` methods.
  Future<void> closePage({required int pageIndex}) async {
    if (_id == null) throw StateError('Please open the PDF first!');

    if (!_pages.contains(pageIndex)) {
      throw StateError('PDF page $pageIndex is not open!');
    }

    await PdfImageRenderer.closePdfPage(pdf: _id!, page: pageIndex);

    _pages.remove(pageIndex);
  }

  /// Returns the number of pages of the PDF.
  /// PDF must be opened with the `open` method before.
  Future<int> getPageCount() async {
    if (_id == null) throw StateError('Please open the PDF first!');

    // Check page count cache.
    if (_pageCount != null) return _pageCount!;

    _pageCount = await PdfImageRenderer.getPDFPageCount(pdf: _id!);

    return _pageCount!;
  }

  /// Gets the [PdfImageRendererPageSize] by the given [pageIndex].
  ///
  /// If the size was already fetched before, it will be returned from memory.
  Future<PdfImageRendererPageSize> getPageSize({required int pageIndex}) async {
    if (_id == null) throw StateError('Please open the PDF first!');

    // Check page sizes cache.
    if (_pageSizes.containsKey(pageIndex)) return _pageSizes[pageIndex]!;

    // Check if the page at given index is already open.
    // If not, auto-open and auto-close the page at given index.
    final autoOpenClosePage = !_pages.contains(pageIndex);

    // Open the page, if required.
    if (autoOpenClosePage) await openPage(pageIndex: pageIndex);

    _pageSizes[pageIndex] =
        await PdfImageRenderer.getPDFPageSize(pdf: _id!, page: pageIndex);

    // Close the page, if required.
    if (autoOpenClosePage) await closePage(pageIndex: pageIndex);

    return _pageSizes[pageIndex]!;
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
    if (_id == null) throw StateError('Please open the PDF first!');

    // Check if the page at given index is already open.
    // If not, auto-open and auto-close the page at given index.
    final autoOpenClosePage = !_pages.contains(pageIndex);

    if (autoOpenClosePage) await openPage(pageIndex: pageIndex);

    final bytes = await PdfImageRenderer.renderPDFPage(
      pdf: _id!,
      page: pageIndex,
      x: x,
      y: y,
      width: width,
      height: height,
      scale: scale,
      background: background,
    );

    if (autoOpenClosePage) await closePage(pageIndex: pageIndex);

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
    if (Platform.isAndroid) {
      final index = await _channel.invokeMethod<int>('closePDFPage', {
        'pdf': pdf,
        'page': page,
      });
      return index;
    } else {
      return page;
    }
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

      width ??= size.width;
      height ??= size.height;
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
