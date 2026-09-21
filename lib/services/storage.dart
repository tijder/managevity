import 'package:hive_ce_flutter/hive_flutter.dart';

export 'package:hive_ce_flutter/hive_flutter.dart' show IsolatedBox;

/// All local storage goes through IsolatedHive. The background sync on Android runs in its
/// own isolate and opens the same boxes as the app; plain Hive cannot cope with that (two
/// writers on one file). IsolatedHive routes the writes of all isolates through a single
/// isolate. The price: every read and write is asynchronous.
bool _initialized = false;

/// [path] exists for tests; the app omits it and gets the platform's app directory.
Future<void> initStorage({String? path}) async {
  if (_initialized) return;
  path == null ? await IsolatedHive.initFlutter() : await IsolatedHive.init(path);
  _initialized = true;
}

Future<IsolatedBox<dynamic>> openStorageBox(String name) async {
  await initStorage();
  return IsolatedHive.openBox<dynamic>(name);
}
