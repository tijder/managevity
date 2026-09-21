# Contributing

## Commits

[Conventional Commits](https://www.conventionalcommits.org/): `<type>[(scope)][!]: <description>`.
The release workflow derives the version bump and the release notes from them:

| Commit | Result |
|---|---|
| `fix: …`, `chore: …`, `docs: …`, … | patch |
| `feat: …` | minor |
| `feat!: …` or `BREAKING CHANGE` in the body | major |

A PR with a subject that does not follow this fails on the *Commit messages* job.

## Before you push

```sh
flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
```

The generated files (`lib/l10n/app_localizations*.dart`, `*.gr.dart`) are committed;
CI checks that they match their source.

## This repo is public

- No real data in tests or examples: no names, membership card numbers, IBANs, tokens,
  gym names or private hostnames. `test/fixtures/` is made up.
- `probe-out/`, `.env`, `key.properties` and keystores are in `.gitignore` and belong there.
- No logos, screenshots or texts from the official app.
