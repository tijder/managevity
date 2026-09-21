import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../providers/lessons_provider.dart';
import '../providers/session_provider.dart';
import '../providers/sync_provider.dart';
import 'storage.dart';

const _taskName = 'managevity.sync';

/// Android only: there a lesson may also have been booked in the official app while this
/// app is closed. On Linux and web the sync simply runs along with use of the app.
Future<void> registerBackgroundSync() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await Workmanager().initialize(backgroundSyncDispatcher);
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: const Duration(hours: 3),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, _) async {
    await initStorage();
    final container = ProviderContainer(retry: (_, _) => null);
    try {
      final settings = await container.read(syncProvider.future);
      if (!settings.enabled) return true;
      final session = await container.read(sessionProvider.future);
      if (!session.ready) return true;
      // Fetches and syncs; throws on a network error, so that we never sync against an
      // empty list.
      await container.read(bookedLessonsProvider.notifier).refreshAndSync();
      return true;
    } on Exception catch (e) {
      debugPrint('[BackgroundSync] $e');
      // true: the next periodic run simply tries again, without a backoff storm.
      return true;
    } finally {
      container.dispose();
    }
  });
}
