import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../services/calendar/calendar_sync_target.dart';
import '../services/sportivity_api.dart';

/// Why something went wrong, independent of language. The services have no BuildContext and
/// should not contain sentences; they give a code, and [describeError] turns it into text in
/// the user's language.
enum AppError {
  notLoggedIn,
  loginFailed,
  tokenRejected,
  noLocations,
  network,
  server,
  lessonNotFound,
  noPdf,
  requestFailed,
  calendarUnavailable,
  calendarPermission,
  calendarAuth,
  calendarNotFound,
  calendarFailed,
}

/// Text for an error, to show on screen. What the server itself says takes precedence: it
/// is more specific than anything we could make of it ("Je hebt geen tegoed meer", i.e.
/// "you have no credit left").
String describeError(AppLocalizations l10n, Object error) => switch (error) {
  // For "no locations" the server text (often just "OK") is a clarification, not a message.
  SportivityException(code: AppError.noLocations, :final serverMessage) =>
    serverMessage == null ? l10n.locationNone : '${l10n.locationNone} (server: $serverMessage)',
  SportivityException(:final serverMessage?) => serverMessage,
  SportivityException(:final code, :final statusCode) => _text(l10n, code, statusCode),
  CalendarSyncException(:final code, :final statusCode, :final detail) => [
    _text(l10n, code, statusCode),
    ?detail,
  ].join(' — '),
  // Anything else is a bug or a platform failure. Its text ("Bad state: No element") means
  // nothing to a user; log it and say so plainly.
  _ => _unexpected(l10n, error),
};

String _unexpected(AppLocalizations l10n, Object error) {
  debugPrint('[error] unexpected: $error');
  return l10n.errorUnexpected;
}

String _text(AppLocalizations l10n, AppError code, int? status) => switch (code) {
  AppError.notLoggedIn => l10n.errorNotLoggedIn,
  AppError.loginFailed => l10n.errorLoginFailed,
  AppError.tokenRejected => l10n.errorTokenRejected,
  AppError.noLocations => l10n.locationNone,
  AppError.network => l10n.errorNetwork,
  AppError.server => l10n.errorServer(status ?? 0),
  AppError.lessonNotFound => l10n.errorLessonNotFound,
  AppError.noPdf => l10n.errorNoPdf,
  AppError.requestFailed => l10n.actionFailed,
  AppError.calendarUnavailable => l10n.errorCalendarUnavailable,
  AppError.calendarPermission => l10n.errorCalendarPermission,
  AppError.calendarAuth => l10n.errorCalendarAuth,
  AppError.calendarNotFound => l10n.errorCalendarNotFound,
  AppError.calendarFailed => l10n.errorCalendarFailed(status ?? 0),
};
