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

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              RaisedButton(
                child: Text('Select PDF'),
                onPressed: () async {
                  String path = await FilePicker.getFilePath(type: FileType.CUSTOM, fileExtension: 'pdf');
                  count = await PdfImageRenderer.getPDFPageCount(path: path);
                  size = await PdfImageRenderer.getPDFPageSize(path: path, page: 0);
                  image = await PdfImageRenderer.renderPDFPage(
                    path: path,
                    page: 0,
                    x: 0,
                    y: 0,
                    width: 100,
                    height: 100,
                    scale: 1,
                    background: '#ffffffff',
                  );
                  setState(() {});
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
