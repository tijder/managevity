import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'l10n/l10n.dart';
import 'router/app_router.dart';
import 'services/background_sync.dart';
import 'services/storage.dart';
import 'theme.dart';
import 'utils/errors.dart';
import 'utils/url_strategy_stub.dart' if (dart.library.js_interop) 'utils/url_strategy_web.dart';

/// Lets code without a BuildContext (the global error handler) show a snackbar.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  await initStorage();
  await initializeDateFormatting();
  await registerBackgroundSync();

  // Last resort for errors nobody caught (a callback without try/catch, a plugin throwing
  // from native code). Better a plain message than a button that silently does nothing.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[error] uncaught: $error\n$stack');
    final context = rootMessengerKey.currentContext;
    if (context != null) {
      rootMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeError(context.l10n, error))));
    }
    return true;
  };

  // No automatic retries. Riverpod 3 re-runs a failed provider up to ten times with growing
  // pauses by default. Here a failure is nearly always "no connection" or "the server said
  // no": retrying behind the user's back hammers someone else's server, and keeps `.future`
  // pending so the real error surfaces late or not at all. Retrying is the user's call, with
  // the button on the error view or a refresh.
  final container = ProviderContainer(retry: (_, _) => null);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ManagevityApp(router: AppRouter(container)),
    ),
  );
}

class ManagevityApp extends StatelessWidget {
  const ManagevityApp({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootMessengerKey,
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Prefix matches on every platform, not just off the web: opening /lesson/5 directly
      // then has the main screen underneath it, so there is something to go back to.
      routerConfig: router.config(includePrefixMatches: true),
      themeMode: ThemeMode.system,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
    );
  }
}
