import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'pdf_image_renderer_platform_interface.dart';

/// PDF according to a [PdfImageRenderer] to convert it to a bitmap.
class PdfImageRenderer {
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
  PdfImageRenderer({
    required String path,
  }) : _path = path;

  String get path => _path;

  /// Open the PDF by the path this [PdfImageRendererPdf] was initialized with.
  ///
  /// Must be closed with the [close] method to free up memory.
  ///
  /// Provide an optional [password] to unlock a locked PDF file.
  /// **Support on Android devices is limited to Android 15.0+ (SDK >= 35). Ignored on devices with Android < 15.0 (SDK < 35).**
  Future<void> open({
    String? password,
  }) async {
    if (_id != null) return;

    _id = await PdfImageRendererPlatform.instance.openPdf(
      path: _path,
      password: password,
    );
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

    await PdfImageRendererPlatform.instance.closePdf(pdf: _id!);

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

    await PdfImageRendererPlatform.instance.openPdfPage(pdf: _id!, page: pageIndex);

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

    await PdfImageRendererPlatform.instance.closePdfPage(pdf: _id!, page: pageIndex);

    _pages.remove(pageIndex);
  }

  /// Returns the number of pages of the PDF.
  /// PDF must be opened with the `open` method before.
  Future<int> getPageCount() async {
    if (_id == null) throw StateError('Please open the PDF first!');

    // Check page count cache.
    if (_pageCount != null) return _pageCount!;

    _pageCount = await PdfImageRendererPlatform.instance.getPdfPageCount(pdf: _id!);

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

    _pageSizes[pageIndex] = await PdfImageRendererPlatform.instance.getPdfPageSize(pdf: _id!, page: pageIndex);

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

    final bytes = await PdfImageRendererPlatform.instance.renderPdfPage(
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
