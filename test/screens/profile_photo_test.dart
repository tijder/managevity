import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/providers/services.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/profile_screen.dart';
import 'package:managevity/widgets/photo_editor.dart';

import '../fixtures/fixtures.dart';

Future<Uint8List> tinyPng() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.teal);
  final image = await recorder.endRecording().toImage(8, 8);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  Future<FakeSportivityApi> pump(WidgetTester tester, Uint8List? picked) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeSportivityApi()..session = const Session(token: 'fake');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          credentialStoreProvider.overrideWithValue(FakeCredentialStore(session: api.session)),
          settingsServiceProvider.overrideWithValue(FakeSettingsService()),
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          photoPickerProvider.overrideWithValue((ImageSource _) async => picked),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Consumer(
            builder: (context, ref, _) => ref.watch(sessionProvider).value?.ready == true
                ? const ProfileScreen()
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  // Choosing a source: in tests the platform is Android, so the chooser sheet comes first.
  Future<void> pickFromGallery(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    // The image is really decoded; that runs outside the test's fake clock.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  testWidgets('a photo is only sent after the confirmation with a preview', (tester) async {
    final png = (await tester.runAsync(tinyPng))!;
    final api = await pump(tester, png);

    await pickFromGallery(tester);
    expect(find.text('Use this photo?'), findsOneWidget);
    expect(api.uploadedPhotos, isEmpty);

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(api.uploadedPhotos.single, png);
    expect(find.text('Photo updated'), findsOneWidget);
  });

  testWidgets('back in the confirmation: nothing leaves the device', (tester) async {
    final api = await pump(tester, (await tester.runAsync(tinyPng))!);
    await pickFromGallery(tester);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.uploadedPhotos, isEmpty);
  });

  testWidgets('choosing cancelled: no dialog, no upload', (tester) async {
    final api = await pump(tester, null);
    await pickFromGallery(tester);
    expect(find.text('Use this photo?'), findsNothing);
    expect(api.uploadedPhotos, isEmpty);
  });

  testWidgets('a file that is not an image gives a message', (tester) async {
    final api = await pump(tester, Uint8List.fromList('not a photo'.codeUnits));
    await pickFromGallery(tester);
    expect(find.text('This file is not an image that can be read.'), findsOneWidget);
    expect(api.uploadedPhotos, isEmpty);
  });
}
