import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/heatmap.dart';
import '../models/invoice.dart';
import '../models/membership.dart';
import '../models/news_item.dart';
import 'services.dart';
import 'session_provider.dart';

/// The ID photo the gym has of you, or null if there is none. An error counts as "no photo"
/// too: it is decoration, not a reason to make a screen fail.
final customerPhotoProvider = FutureProvider<Uint8List?>((ref) async {
  // Watch the session: after logging out and back in, the previous user's photo must not
  // linger here, not even when the location is the same.
  ref.watch(sessionProvider);
  try {
    final bytes = await ref.watch(apiProvider).customerPhoto(ref.watch(locationIdProvider));
    return bytes == null || bytes.isEmpty ? null : bytes;
  } on Exception {
    return null;
  }
});

final userContentProvider = FutureProvider.autoDispose<UserContent>(
  (ref) => ref.watch(apiProvider).userContent(locationId: ref.watch(locationIdProvider)),
);

final membershipsProvider = FutureProvider.autoDispose<List<Membership>>(
  (ref) => ref.watch(apiProvider).memberships(ref.watch(locationIdProvider)),
);

final addonsProvider = FutureProvider.autoDispose<List<Addon>>(
  (ref) => ref.watch(apiProvider).addons(ref.watch(locationIdProvider)),
);

final heatmapWeekProvider = FutureProvider.autoDispose<List<HeatmapCell>>(
  (ref) => ref.watch(apiProvider).heatmapWeek(ref.watch(locationIdProvider)),
);

final heatmapDayProvider = FutureProvider.autoDispose.family<List<HeatmapCell>, DateTime>(
  (ref, day) => ref.watch(apiProvider).heatmapDay(ref.watch(locationIdProvider), day),
);

final newsProvider = FutureProvider.autoDispose<List<NewsItem>>(
  (ref) => ref.watch(apiProvider).news(ref.watch(locationIdProvider)),
);

final notificationsProvider = FutureProvider.autoDispose<List<NewsItem>>(
  (ref) => ref.watch(apiProvider).notifications(ref.watch(locationIdProvider)),
);

/// `all: false` is the server's own definition of "still to be paid".
final invoicesProvider = FutureProvider.autoDispose.family<List<Invoice>, bool>(
  (ref, all) => ref.watch(apiProvider).invoices(ref.watch(locationIdProvider), all: all),
);

final contactHtmlProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(apiProvider).contactInformationHtml(ref.watch(locationIdProvider)),
);

final requirementsHtmlProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(apiProvider).requirementsHtml(ref.watch(locationIdProvider)),
);
