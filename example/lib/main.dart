import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int pageIndex = 0;
  Uint8List? image;

  bool open = false;

  PdfImageRendererPdf? pdf;
  int? count;
  PdfImageRendererPageSize? size;

  bool cropped = false;

  int asyncTasks = 0;

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
    const count = 50;

    await pdf!.openPage(pageIndex: pageIndex);

    size = await pdf!.getPageSize(pageIndex: pageIndex);

    asyncTasks = count;

    final renderFutures = <Future<Uint8List?>>[];
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

      renderFutures.add(future);

      future.then((value) {
        setState(() {
          asyncTasks--;
        });
      });
    }

    await Future.wait(renderFutures);

    await pdf!.closePage(pageIndex: pageIndex);
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
                icon: const Icon(Icons.crop),
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
                  child: const Text('Select PDF'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom, allowedExtensions: ['pdf']);

                    if (result != null) {
                      await openPdf(path: result.paths[0]!);
                      pageIndex = 0;
                      count = await pdf!.getPageCount();
                      await renderPage();
                    }
                  },
                ),
                if (count != null) Text('The selected PDF has $count pages.'),
                if (image != null)
                  Text('It is ${size!.width} wide and ${size!.height} high.'),
                if (open == true)
                  ElevatedButton(
                    child: const Text('Close PDF'),
                    onPressed: () async {
                      await closePdf();
                    },
                  ),
                if (image != null) ...[
                  const Text('Rendered image area:'),
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
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      ),
                      TextButton.icon(
                        onPressed: pageIndex < (count! - 1)
                            ? () async {
                                pageIndex += 1;
                                await renderPage();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                      ),
                    ],
                  ),
                  if (asyncTasks <= 0)
                    TextButton(
                      onPressed: () {
                        renderPageMultipleTimes();
                      },
                      child: const Text('Async rendering test'),
                    ),
                  if (asyncTasks > 0) Text('$asyncTasks remaining tasks'),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
