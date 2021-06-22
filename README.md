# pdf_image_renderer

[![pub package](https://img.shields.io/pub/v/pdf_image_renderer.svg)](https://pub.dartlang.org/packages/pdf_image_renderer)

Renders PDFs to bitmaps using native renderers.

## Usage

**See the example folder for a fully working flutter example.**

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Uint8List image;

  void renderPdfImage() async {
    // Get a path from a pdf file (we are using the file_picker package (https://pub.dev/packages/file_picker))
    String path = await FilePicker.getFilePath(type: FileType.custom, allowedExtensions: ['pdf']);

    // Initialize the renderer
    final pdf = PdfImageRendererPdf(path: path);

    // open the pdf document
    await pdf.open()

    // open a page from the pdf document using the page index
    await pdf.openPage(pageIndex: 0);

    // get the render size after the page is loaded
    final size = await pdf.getPageSize(pageIndex: 0);

    // get the actual image of the page
    final img = await pdf.renderPage(
          pageIndex: pageIndex,
          x: 0,
          y: 0,
          width: size.width, // you can pass a custom size here to crop the image
          height: size.height, // you can pass a custom size here to crop the image
          scale: 1, // increase the scale for better quality (e.g. for zooming)
          background: Colors.white,
        );

    // close the page again
    await pdf.closePage(pageIndex: 0);

    // close the PDF after rendering the page
    pdf.close();

    // use setState to update the renderer
    setState(() {
      image = img;
    });
  }

  @override
  void initState() {
    super.initState();
  }


  // you can use this image later in your build function
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('pdf_image_renderer'),
          ),
          body: Center(
            child: image != null ? Image(image: MemoryImage(image)) : Text("Loading..."),
          )
        )
    );
  }
}

```
