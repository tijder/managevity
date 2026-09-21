# Managevity

**Managevity for Sportivity** — an unofficial client for booking your gym classes and
getting them into your own calendar, without the official app.

> This project is **not affiliated with or endorsed by b.o.s.s. or Sportivity**. It uses
> the API that the platform itself documents publicly
> (`https://www.sportivity.com/rest-doc/`), with your own member account. Use it for
> yourself and in moderation: book what you actually intend to attend.

## What it does

- Schedule per day, filtering by activity, class details
- Booking, joining the waiting list, cancelling, favourites
- **One-way calendar sync**: booked classes show up in your calendar and disappear when
  you cancel. Your choice of
  - a **calendar on the device** (Android; for example a Nextcloud calendar via DAVx⁵), or
  - **CalDAV** directly (Nextcloud and other servers), with an app password.

  The app only touches events it created itself.
- How busy the gym is, news and notifications, invoices (PDF), your details,
  memberships and add-ons (read-only), contact details and house rules

Deliberately **not** included: changing, freezing or cancelling a membership, and paying.
A class that costs money is only booked after a confirmation that shows the amount.

Platforms: Android, Linux and web.

- Every page has its own URL in the web version, so lessons and pages can be linked and
  bookmarked; a link still leads to its page after signing in.

## Demo login

Signing in with username `demo` and password `demo` opens a built-in demo environment with
made-up data. It never contacts the real server, nothing is really booked, and its state
resets when the app restarts. It exists so app-store reviewers (and curious people) can try
the app without a gym account.

## Web and the Docker image

The API sends no CORS headers, so a browser cannot reach it directly. The image therefore
serves the web version **and** proxies the API on the same origin:

```sh
podman run --rm -p 8080:8080 ghcr.io/<owner>/managevity:latest
```

| Variable | Default | Meaning |
|---|---|---|
| `SPORTIVITY_UPSTREAM` | `https://www.sportivity.com` | where `/api/` goes |
| `NEXTCLOUD_UPSTREAM` | *(empty)* | set to `https://cloud.example.org` to enable CalDAV sync in the browser; the proxy then serves `/remote.php/dav/` |
| `UPSTREAM_CA_FILE` | system bundle | CA bundle for the upstreams, for example with a private CA |

The proxy only knows these fixed upstreams and never forwards to a host taken from the
request. The image runs as non-root on port 8080 and has `/healthz`. In the browser your
password is never stored.

## Developer information

| | |
|---|---|
| Flutter | see `environment.flutter` in `pubspec.yaml` |
| State | Riverpod |
| Routing | auto_route |
| HTTP | dio |
| Storage | Hive (settings, cache), the platform keyring (passwords) |

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run -d linux
flutter test
tool/build-image.sh          # web build + image managevity:dev
```

The source language of the localizations is English: `lib/l10n/app_en.arb` is the
template, `app_nl.arb` the Dutch translation.

`tool/probe.dart` records how the API behaves in real life (see the header of that
file). It writes to `probe-out/`, which does **not** belong in git: it contains your own
data.

Contributing: see [CONTRIBUTING.md](CONTRIBUTING.md). Licence: GPL-3.0-or-later.
