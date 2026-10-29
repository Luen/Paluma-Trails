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

## Design and branding

Read [`docs/branding.md`](docs/branding.md) before changing UI, colours, type,
icons or store artwork. Colours come from the theme, `BrandColors` or
`MapPalette`, never a new hex value in a widget. The brand artwork is generated
by [`tools/brand/`](tools/brand/README.md); run
`python tools/brand/colour_check.py` after touching any palette. UI pull
requests complete the brand review checklist in the PR template.

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
- Use **Squash and merge** so each PR becomes one Conventional Commit.
  Release Please reads those commits; merge commits make it list the same
  change twice in the changelog. The exception is the `dev` → `main`
  promotion PR: merge that one with a merge commit so the individual commits
  reach `main` and appear in the changelog.

## Releasing

Promote `dev` to `main`. Release Please opens a release PR with the next
version and changelog; merging it creates the `v*` tag, and the Release
workflow builds the AAB, the per-ABI APKs and the web bundle. See
[docs/release.md](docs/release.md) for the versioning, the release token,
signing secrets and the Play download budget.

## Adding dependencies

Please open an issue first for anything beyond small, well-maintained packages.
Offline capability and licence compatibility are the main filters (see
`docs/decisions/`).
