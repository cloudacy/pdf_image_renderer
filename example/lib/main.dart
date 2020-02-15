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
  int count;
  PdfImageRendererPageSize size;
  Uint8List image;

  String path;

  bool cropped = false;

  @override
  void initState() {
    super.initState();
  }

  rerender() async {
    final i = await PdfImageRenderer.renderPDFPage(
      path: path,
      page: 0,
      x: 0,
      y: 0,
      width: cropped ? 100 : size.width,
      height: cropped ? 100 : size.height,
      scale: 1,
      background: '#ffffffff',
    );

    setState(() {
      image = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          actions: <Widget>[
            IconButton(
                icon: Icon(Icons.crop),
                onPressed: () {
                  cropped = !cropped;
                  rerender();
                })
          ],
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              RaisedButton(
                child: Text('Select PDF'),
                onPressed: () async {
                  path = await FilePicker.getFilePath(type: FileType.CUSTOM, fileExtension: 'pdf');
                  count = await PdfImageRenderer.getPDFPageCount(path: path);
                  size = await PdfImageRenderer.getPDFPageSize(path: path, page: 0);

                  rerender();
                },
              ),
              if (count != null) Text('The selected PDF has $count pages.'),
              if (image != null) Text('It is ${size.width} wide and ${size.height} high.'),
              if (image != null) ...[
                Text('Rendered image area:'),
                Image(image: MemoryImage(image)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
