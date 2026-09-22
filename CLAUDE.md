# CLAUDE.md

Managevity: unofficial Flutter client for the Sportivity API (Android, Linux, web) with
one-way calendar sync. **The repo is public** — see "Public" at the bottom.

Code, comments, tests and docs are English, and the localization template is
`lib/l10n/app_en.arb` (`app_nl.arb` is the Dutch translation).

## Commands

```sh
flutter pub get
flutter gen-l10n                                          # after every change in lib/l10n/*.arb
dart run build_runner build --delete-conflicting-outputs  # after a change in routes/@RoutePage
flutter analyze
flutter test                                              # --plain-name '…' for a single test
flutter run -d linux
tool/build-image.sh                                       # web build + podman build
dart run tool/probe.dart                                  # real API, GETs only; see its header
# Render every screen (phone + desktop, fake data) to doc/screenshots/ — look at these
# for every change to the design, instead of guessing:
flutter test --tags golden --update-goldens test/screenshots/screenshots_test.dart
```

Generated files (`app_localizations*.dart`, `app_router.gr.dart`) are committed;
the CI job `test` fails when they are out of date.

## Architecture

Layer-first: `lib/{models,services,providers,router,screens,widgets,utils,l10n}`.

- **`services/sportivity_api.dart`** — the only place that knows the API. Things that
  are not in the Swagger spec and were established here (21/22-09-2026):
  - without `Accept: application/json` the server answers in **XML**;
  - errors arrive as **HTTP 200** with the outcome in the body: `HttpStatusCode` for
    `Login`, `Response: "Wrong token"` for everything else. `_send` translates that into a
    `SportivityException` and, when a token is refused, tries to log in again once
    (`onSessionExpired`). Requests refused at the same time share one renewal, and requests
    that start during it wait for it;
  - the API sends **no CORS headers**, hence `API_BASE` (dart-define) and the proxy;
  - `SpotsInt` is the number of people **going**, not the spots free (22-09-2026, 231
    lessons: `Full` exactly when it equals `MaximumParticipants`). `Lesson.participants`
    holds it, `spotsLeft`/`isFull` are derived. Dates go as `yyyy-MM-dd`.
  `BookingStatus` in real data: `Gereserveerd` / `Reservering_vast` (booked), `Aangemeld`
  (past lessons: attended), absent (not booked); see `models/lesson.dart`. Still open: the
  waiting-list value (recognised by keyword), and `Authorization` is still tried out while
  logging in although the probe found `Bearer`.
- **Demo mode**: `services/demo_server.dart` is a Dio `HttpClientAdapter` that answers like
  the real server; `SportivityApi.login('demo','demo')` and the `session` setter route to it
  (a restored demo session must go back to the demo, never to the network with a made-up
  token). It is a transport-level mock on purpose, so a demo session exercises the real
  client, parsing and error handling. Never write a test that logs in with demo + a wrong
  password: that is not the demo and hits the real server.
- **Models** are immutable, with a hand-written `tryFromJson` that never throws
  (`utils/json.dart`): the API sometimes delivers numbers as strings and `UTC…` times
  without a zone. `BookingStatus` is an extension type around a **non-nullable** String —
  around a nullable one it drops out in a `??`.
- **Calendar sync** (`services/calendar/`): `SyncEngine` compares the booked lessons with
  its own index (per target calendar) and does upsert/delete through a `CalendarSyncTarget`
  (`CalDavTarget`, `DeviceCalendarTarget`). It only touches events that are in the index,
  and saves the index after every write (the OS may stop the background task halfway);
  lessons that are *in the past* stay where they are. It is only called after a successful
  fetch — an empty list caused by a network error, or the offline copy, must never reach the
  calendar (`BookedLessonsNotifier.refreshAndSync`). On Android it also runs every three hours
  via workmanager (`services/background_sync.dart`), which goes through
  `BookedLessonsFetcher` directly: reading the notifier would run its build and fetch twice.
  `SyncNotifier.run` never drops a list: one that arrives mid-sync is synced right after,
  and a lock held by the other isolate is waited for. Status is written onto the settings
  as they are in storage *now* (`_update`), not as they were when the sync started.
- **Booking**: once `joinLesson` succeeds, nothing after it may throw — a failed refresh is
  logged, and the calendar sync is not awaited.
- **Storage** goes through `services/storage.dart` on **IsolatedHive**, never on plain Hive:
  the background sync is a second isolate that opens the same boxes. Every read and write is
  therefore async.
- **One sync at a time, across isolates**: `services/sync_lock.dart` uses the
  `IsolateNameServer` as the lock. Not a file lock — that holds per process, and the app and
  the background task *are* one process (tried out with a real second isolate in
  `test/services/storage_test.dart`). A lock held by an isolate that died is taken over
  after an unanswered ping.
- **Go easy on someone else's server**: the schedule is fetched per week
  (`scheduleWeekProvider`, kept for ten minutes; an empty day is asked for once more on its
  own in case the server shortens the range). Details of booked lessons stay in the cache
  for a day, details of past lessons permanently (`PastLessonDetails`, fetched per card as
  it comes into view).
- **Errors** carry an `AppError` code, not a sentence; `describeError` in `utils/errors.dart`
  turns it into text in the user's language. What the server itself says takes precedence.
  Never show `'$e'`.
- **Errors on screen**: nothing shows `'$e'`. `describeError` turns an `AppError` code into
  localized text, unexpected errors become one plain sentence (the raw text is logged), a
  failed refresh is reported by `Refreshable`/`RefreshAction` in a snackbar while the old
  content stays, and `PlatformDispatcher.onError` in `main.dart` is the last resort.
- **Offline**: when a list comes from the cache because the server was unreachable, the
  provider reports it to `offlineProvider` and `MainScreen` shows a strip ("Offline: showing
  what was loaded earlier"). A successful fetch clears it. Offline with nothing cached is an
  error ("no connection"), never an empty list. The report goes through a microtask because
  Riverpod forbids changing one provider while another is being built. Only
  `SportivityException.isUnreachable` (no connection, or 502/503/504 from the proxy) counts
  as offline; a server error or a refused token stays an error.
- **Dates**: a day further is `addDays` (calendar arithmetic), never
  `.add(Duration(days: n))` — across the end of summer time that lands on 23:00 the same
  day. CI runs the tests with `TZ=Europe/Amsterdam` for this reason.
- **Every page has a URL** (path strategy on the web, nginx falls back to `index.html`, and
  `router.config(includePrefixMatches: true)` puts the main screen under a deep page so "back"
  works). `SessionGuard` remembers the requested URL in `pendingPathProvider` — taken from
  `resolver.pendingRoutes.last`, because for a deep link the guard that runs belongs to the
  main screen, not to the destination. `continueAfterSession` (login, location choice, demo
  button) consumes it only once the session is ready, and skips the location screen when
  there is just one location. `/login` and `/location` are never a destination.
- **Public pages and SEO**: `/about` (`screens/about_screen.dart`) has no guard and is linked
  from the login screen. Flutter paints to a canvas that crawlers cannot read, so
  `web/index.html` carries the description, Open Graph/Twitter tags, JSON-LD
  (`SoftwareApplication`) and a static text block (`#static-content`) that doubles as the
  loading screen and is removed on `flutter-first-frame`. Keep its claims in step with the
  About screen and with reality (no tracking, no own server). URLs in the head are relative:
  the app does not know its host, so there is no canonical link or sitemap.
- **No automatic retries**: the `ProviderContainer` in `main.dart` and in the background task
  is created with `retry: (_, _) => null`. Riverpod 3 otherwise re-runs a failed provider up to
  ten times: that hammers someone else's server and keeps `.future` pending, so the real error
  shows up late or as "disposed during loading". Tests that expect a failure need the same.
- **Sync failures** are `SyncFailure` objects carrying the error, not sentences; the engine does
  not know the user's language. `sync_provider.dart` turns the first one into "lastError" via
  `describeError`.
- Pitfall: `future.whenComplete(() => map.remove(key))` returns the removed future and
  whenComplete waits for it — so for itself. Use braces.
- **Secrets** live in `CredentialStore` (keyring). On web there is no keyring, so passwords
  are never stored there; only the session token, in `sessionStorage` (survives a reload,
  gone with the tab).
- **Router**: auto_route with `SessionGuard` (not logged in → login, no location →
  location picker). `main.dart` creates the `ProviderContainer` itself so the guard can
  reach it.
- **Money**: `joinLesson` sends `BuyLesson: false`; only after `ShowFinancialPopup` *and* a
  confirmation that shows the amount does it go again with `true`. Changing a membership,
  toggling add-ons and paying are deliberately not in the app.
- **Design**: content does not stretch on wide screens — `widgets/responsive.dart`
  (`ResponsiveListView` caps the width, `CardGrid` puts cards side by side). Loading goes
  through `AsyncView` with a `placeholder` from `widgets/placeholders.dart` (Skeletonizer);
  while refreshing, the old content stays in place.
- **Tests**: hand-written fakes in `test/fixtures/fixtures.dart`, wired in with Riverpod
  overrides (`test/screens/helpers.dart`); HTTP with a fake `HttpClientAdapter`.

## Docker and CI

`Dockerfile` only copies `build/web` into nginx-unprivileged; it does not build Flutter.
`docker/default.conf.template` + `docker/18-dav-proxy.sh` make up the proxy: `/api/` →
Sportivity, and `/remote.php/dav/` → `NEXTCLOUD_UPSTREAM` when that is set (same path as
Nextcloud, so DAV hrefs stay correct). Watch out with nginx: an `add_header` in a
`location` switches off all `add_header`s of the server block — hence the `map` for
`Cache-Control`.

`.github/workflows/build.yml` is reusable and is called by `workflow.yml` (push/PR) and
`release.yml` (nightly, semver from conventional commits). The version is passed in as
`--build-name/--build-number`; there is no bump commit. Android signing via
`android/key.properties`, written from secrets in CI; without secrets, debug signing.

## Public

No real account data, gym names, private hostnames or tokens in code, tests, examples or
commit messages. `probe-out/` and `.env` stay out of git. "Sportivity" does not appear in
the app name, package name, applicationId or icon — only descriptively.
