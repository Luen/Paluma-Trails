# Contributing to Paluma Trails

Thanks for helping. This project is for people walking the Paluma tracks, so
correctness and offline behaviour matter more than speed.

## Branch flow

`dev` is the default branch. All changes land through pull requests.

```
feature branch ──PR──> dev ──promotion PR──> main (release)
```

- Branch names: `feat/…`, `fix/…`, `docs/…`, `chore/…`, `content/…`.
- PRs must be green on CI before merge.
- Never push directly to `main`.

## Getting set up

```bash
# Flutter app
cd app
flutter pub get
flutter run            # pick a device; iOS simulator or Chrome for web

# Content CLI (Dart, no Flutter required)
cd tools/paluma_cli
dart pub get
dart run bin/paluma_cli.dart --help
```

## Everyday commands

```bash
# Content: validate the data against the schema, rebuild the bundle the app loads
dart run tools/paluma_cli/bin/paluma_cli.dart content validate
dart run tools/paluma_cli/bin/paluma_cli.dart content graph
dart run tools/paluma_cli/bin/paluma_cli.dart bundle build

# App
cd app && flutter analyze && flutter test

# Format everything
dart format app tools
```

CI runs exactly these checks, plus `flutter build web --release` and a debug APK.

## Editing content

- Edit files under `content/data/paluma/`. Never edit `app/assets/bundle/**`
  by hand — it is generated. Run `bundle build` afterwards, and commit the result.
- Numbers about tracks (distances, times) are computed by the tool and labelled
  as estimates everywhere they are shown.
- Every fact about a place needs a source. Add it to the POI's `sources` field.
  If you cannot cite it, mark it as needing verification in the relevant issue
  instead of writing it as fact.

## Commit messages

Conventional Commits, because release tooling reads them:

```
feat(app): junction cards with distances and estimated times
fix(content): correct Garde's Clearing coordinates
docs(adr): record offline map stack decision
```

## Pull requests

- Keep them small and explain the "why" in the description.
- Link the issue you are working on (`Part of #12`, `Closes #64`).
- Screenshots for UI changes; offline behaviour tested with the device in flight
  mode where relevant.

## Adding dependencies

Please open an issue first for anything beyond small, well-maintained packages.
Offline capability and licence compatibility are the main filters (see
`docs/decisions/`).
