import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int pageIndex = 0;
  Uint8List? image;

  bool open = false;

  PdfImageRendererPdf? pdf;
  int? count;
  PdfImageRendererPageSize? size;

  bool cropped = false;

  int parallelTasks = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> renderPage() async {
    size = await pdf!.getPageSize(pageIndex: pageIndex);
    final i = await pdf!.renderPage(
      pageIndex: pageIndex,
      x: cropped ? 100 : 0,
      y: cropped ? 100 : 0,
      width: cropped ? 100 : size!.width,
      height: cropped ? 100 : size!.height,
      scale: 3,
      background: Colors.white,
    );

    setState(() {
      image = i;
    });
  }

  Future<void> renderPageMultipleTimes() async {
    final count = 50;
    size = await pdf!.getPageSize(pageIndex: pageIndex);

    parallelTasks = count;

    for (var i = 0; i < count; i++) {
      final future = pdf!.renderPage(
        pageIndex: pageIndex,
        x: (size!.width / count * i).round(),
        y: (size!.height / count * i).round(),
        width: (size!.width / count).round(),
        height: (size!.height / count).round(),
        scale: 3,
        background: Colors.white,
      );

      future.then((value) {
        setState(() {
          parallelTasks--;
        });
      });
    }
  }

  Future<void> openPdf({required String path}) async {
    if (pdf != null) {
      await pdf!.close();
    }
    pdf = PdfImageRendererPdf(path: path);
    await pdf!.open();
    setState(() {
      open = true;
    });
  }

  Future<void> closePdf() async {
    if (pdf != null) {
      await pdf!.close();
      setState(() {
        pdf = null;
        open = false;
      });
    }
  }

  Future<void> openPdfPage({required int pageIndex}) async {
    await pdf!.openPage(pageIndex: pageIndex);
  }

  Future<void> closePdfPage({required int pageIndex}) async {
    await pdf!.closePage(pageIndex: pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          actions: [
            if (open == true)
              IconButton(
                icon: Icon(Icons.crop),
                onPressed: () async {
                  cropped = !cropped;
                  await renderPage();
                },
              )
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ElevatedButton(
                  child: Text('Select PDF'),
                  onPressed: () async {
                    final result =
                        await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

                    if (result != null) {
                      await openPdf(path: result.paths[0]!);
                      pageIndex = 0;
                      count = await pdf!.getPageCount();
                      await renderPage();
                    }
                  },
                ),
                if (count != null) Text('The selected PDF has $count pages.'),
                if (image != null) Text('It is ${size!.width} wide and ${size!.height} high.'),
                if (open == true)
                  ElevatedButton(
                    child: Text('Close PDF'),
                    onPressed: () async {
                      await closePdf();
                    },
                  ),
                if (image != null) ...[
                  Text('Rendered image area:'),
                  Image(image: MemoryImage(image!)),
                ],
                if (open == true) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: pageIndex > 0
                            ? () async {
                                pageIndex -= 1;
                                await renderPage();
                              }
                            : null,
                        icon: Icon(Icons.chevron_left),
                        label: Text('Previous'),
                      ),
                      TextButton.icon(
                        onPressed: pageIndex < (count! - 1)
                            ? () async {
                                pageIndex += 1;
                                await renderPage();
                              }
                            : null,
                        icon: Icon(Icons.chevron_right),
                        label: Text('Next'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      renderPageMultipleTimes();
                    },
                    child: Text('Parallel rendering test'),
                  ),
                  if (parallelTasks > 0) Text('Open Tasks $parallelTasks'),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
