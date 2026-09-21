import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/utils/photo.dart';

/// A PNG of [width]×[height] filled with noise, so that it does not compress to almost nothing.
Future<Uint8List> noise(int width, int height) async {
  final pixels = Uint8List(width * height * 4);
  var seed = 1;
  for (var i = 0; i < pixels.length; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    pixels[i] = i % 4 == 3 ? 255 : seed >> 16 & 0xff;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final image = (await (await descriptor.instantiateCodec()).getNextFrame()).image;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

Future<(int, int)> sizeOf(Uint8List bytes) async {
  final image = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
  return (image.width, image.height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a small photo passes through unchanged', (tester) async {
    await tester.runAsync(() async {
      final small = await noise(200, 300);
      expect(await preparePhoto(small), same(small));
    });
  });

  testWidgets('a large photo is scaled down, keeping its aspect ratio', (tester) async {
    await tester.runAsync(() async {
      final portrait = await noise(1500, 2000);
      expect(portrait.length, greaterThan(kPhotoMaxBytes));
      final prepared = await preparePhoto(portrait);
      expect(await sizeOf(prepared), (540, 720));

      expect(await sizeOf(await preparePhoto(await noise(2000, 1000))), (720, 360));
    });
  });

  testWidgets('not an image: a clean error', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        preparePhoto(Uint8List.fromList('this is text, not a photo'.codeUnits)),
        throwsFormatException,
      );
    });
  });
}
