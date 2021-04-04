import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:pdf_image_renderer/pdf_image_renderer.dart';

void main() {
  const channel = MethodChannel('pdf_image_renderer');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    // expect(await PdfImageRenderer.platformVersion, '42');
  });
}
