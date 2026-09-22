import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/guest_pass.dart';
import '../models/heatmap.dart';
import '../models/invoice.dart';
import '../models/membership.dart';
import '../models/news_item.dart';
import '../models/payment.dart';
import '../models/profile_settings.dart';
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

/// The customer's add-ons plus those that can still be added to one of their memberships.
/// The per-membership lists are an extra: when one fails, the customer's own list remains.
final addonsProvider = FutureProvider.autoDispose<List<Addon>>((ref) async {
  final api = ref.watch(apiProvider);
  final own = await api.addons(ref.watch(locationIdProvider));
  final memberships = await ref.watch(membershipsProvider.future).catchError((_) => <Membership>[]);
  final byId = {for (final a in own) a.id: a};
  for (final m in memberships) {
    final more = await api.membershipAddons(m.id).catchError((_) => <Addon>[]);
    for (final a in more) {
      byId.putIfAbsent(a.id, () => a);
    }
  }
  return byId.values.toList();
});

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

final guestPassesProvider = FutureProvider.autoDispose<List<GuestPass>>(
  (ref) => ref.watch(apiProvider).guestPasses(ref.watch(locationIdProvider)),
);

final guestAllowanceProvider = FutureProvider.autoDispose<GuestAllowance>(
  (ref) => ref.watch(apiProvider).guestAllowance(ref.watch(locationIdProvider)),
);

final optInProvider = FutureProvider.autoDispose<OptInSettings>(
  (ref) => ref.watch(apiProvider).optIn(ref.watch(locationIdProvider)),
);

final countriesProvider = FutureProvider.autoDispose<List<Country>>(
  (ref) => ref.watch(apiProvider).countries(ref.watch(locationIdProvider)),
);

final creditOptionsProvider = FutureProvider.autoDispose<List<CreditOption>>(
  (ref) => ref.watch(apiProvider).creditOptions(ref.watch(locationIdProvider)),
);

final cancellationReasonsProvider = FutureProvider.autoDispose<List<CancellationReason>>(
  (ref) => ref.watch(apiProvider).cancellationReasons(ref.watch(locationIdProvider)),
);
