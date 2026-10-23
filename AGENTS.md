# Agent instructions

These instructions are for coding agents working in this repository. Read the
linked documents before changing an area; the architecture decisions are
authoritative.

## Read first

- **Branding and visual language:** [docs/branding.md](docs/branding.md). Read
  this before changing UI, colours, typography, icons, splash screens, store
  artwork, screenshots or user-facing tone.
- **Architecture decisions:** [docs/decisions/](docs/decisions/). ADRs 0001–0007
  are authoritative; amend rather than silently changing a decision.
- **Content model:** [docs/content-model.md](docs/content-model.md).
- **Location and junction distances:** [docs/location.md](docs/location.md).
- **Release process:** [docs/release.md](docs/release.md).
- **Signing and store credentials:** [docs/signing.md](docs/signing.md).
- **Web deployment:** [docs/web-deployment.md](docs/web-deployment.md).

## Project shape

- `app/` — Flutter app (Android, iOS and web).
- `content/data/` — the source of truth for tracks, junctions, POIs and park
  facts.
- `app/assets/bundle/` — generated offline bundle consumed by the app.
- `tools/paluma_cli/` — Dart content validator/bundler.
- `tools/basemap/` — offline PMTiles pipeline.
- `tools/brand/` — wordmark/lockup/marketing generator and colour checks.
- `.github/workflows/` — CI, release and release-please.

## Everyday commands

```sh
# App
cd app
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test

# Content
cd tools/paluma_cli && dart pub get && cd ../..
dart run tools/paluma_cli/bin/paluma_cli.dart content validate
dart run tools/paluma_cli/bin/paluma_cli.dart bundle build --out /tmp/bundle
diff -r /tmp/bundle app/assets/bundle

# Brand artwork and colour checks (from the repository root)
python tools/brand/colour_check.py
python tools/brand/build_brand.py && tools/brand/render_png.sh

# Generated artwork and signing helper
cd app
tool/check_generated_icons.sh
tool/test_create_upload_keystore.sh
```

## Non-negotiables

- **Offline first.** Anything a walker reads on the trail must work with the
  network off. If a feature cannot, label it clearly (for example the weather
  card's “fetched at”).
- **Estimated times are estimates.** Keep the “estimated” wording in UI,
  content and store copy.
- **Content source of truth.** Edit `content/data/**` and regenerate the bundle;
  do not hand-edit `app/assets/bundle/content/**`.
- **Branding.** Use the palette and rules in
  [docs/branding.md](docs/branding.md). Do not add unexplained hex values to
  widgets; use `Theme.of(context).colorScheme` and `textTheme`, `BrandColors`
  on rainforest brand surfaces, and `MapPalette` for map features. Keep original
  artwork and record licences for new images.
- **Outdoor usability.** Preserve 48 dp controls, high-contrast sunlight mode,
  battery saver behaviour and AA contrast. Do not make essential actions depend
  on a hidden gesture.
- **Safety copy.** Emergency and hazard messages stay plain, prominent and
  free of playful language.
- **Secrets never enter git.** Do not commit keystores, `key.properties`,
  service-account JSON, Apple private keys or environment files.
- **Branch flow.** Work from `dev` on a short-lived branch
  (`feat/…`, `fix/…`, `docs/…`, `chore/…`). Never push directly to `main`.
  Squash-merge feature PRs; the `dev` → `main` promotion uses a merge commit so
  release-please sees the individual commits.
- **Conventional Commits.** Use `feat(scope):`, `fix(scope):`, `docs(scope):`,
  etc. Release Please derives versions and the changelog from them.
- **Release tags.** Do not create `v*` tags by hand for normal releases; merge
  the release-please PR. Manual tags are only for hotfixes/prereleases.

## Before opening a pull request

1. Run the relevant format, analyze and test commands above.
2. For content changes, validate and confirm the generated bundle diff is
   committed.
3. For icon/splash/store changes, run `tool/check_generated_icons.sh` and inspect
   the small-size outputs.
4. For UI changes, check light, dark and sunlight modes and large text.
5. Link the issue and explain the user-visible change; include screenshots for
   UI work.
