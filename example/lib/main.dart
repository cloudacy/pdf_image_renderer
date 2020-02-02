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
                  image = await PdfImageRenderer.renderPDF(path);
                  print(image);
                  setState(() {});
                },
              ),
              if (image != null) Image(image: MemoryImage(image))
            ],
          ),
        ),
      ),
    );
  }
}
