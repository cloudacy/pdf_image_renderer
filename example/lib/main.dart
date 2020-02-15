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
  int pageIndex = 0;
  PdfImageRendererPageSize size;
  Uint8List image;

  String path;

  bool cropped = false;

  @override
  void initState() {
    super.initState();
  }

  rerender() async {
    size = await PdfImageRenderer.getPDFPageSize(path: path, page: pageIndex);
    final i = await PdfImageRenderer.renderPDFPage(
      path: path,
      page: pageIndex,
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

                  rerender();
                },
              ),
              if (count != null) Text('The selected PDF has $count pages.'),
              if (image != null) Text('It is ${size.width} wide and ${size.height} high.'),
              if (image != null) ...[
                Text('Rendered image area:'),
                Image(image: MemoryImage(image)),
              ],
              if (count != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FlatButton.icon(
                      onPressed: pageIndex > 0
                          ? () {
                              pageIndex -= 1;
                              rerender();
                            }
                          : null,
                      icon: Icon(Icons.chevron_left),
                      label: Text('Previous'),
                    ),
                    FlatButton.icon(
                      onPressed: pageIndex < (count - 1)
                          ? () {
                              pageIndex += 1;
                              rerender();
                            }
                          : null,
                      icon: Icon(Icons.chevron_right),
                      label: Text('Next'),
                    )
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}
