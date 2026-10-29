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
- **Route planning:** [docs/planning.md](docs/planning.md).
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
- `.github/workflows/` — CI, release, release-please, nightly deps release and release-publish.

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
dart run tools/paluma_cli/bin/paluma_cli.dart content print-map

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
- **Printable map.** Regenerate `app/web/printable-map.html` after source content
  or map palette changes. CI checks freshness. The page contains inline SVG
  and needs no external assets; preserve its credits, unverified notice and
  estimated-time labels. See [docs/printable-map.md](docs/printable-map.md).
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
  Never suggest ordinary SMS directly to 000/112 or imply that 112 creates
  mobile reception. Check current official guidance and retain offline source
  labels; dedicated NRS relay services are a separate subject. See
  [the contact-guidance research](content/research/emergency-contact-guidance.md).
- **Secrets never enter git.** Do not commit keystores, `key.properties`,
  service-account JSON, Apple private keys or environment files.
- **Branch flow.** Work from `dev` on a short-lived branch
  (`feat/…`, `fix/…`, `docs/…`, `chore/…`). Never push directly to `main`.
  Squash-merge feature PRs; the `dev` → `main` promotion uses a merge commit so
  release-please sees the individual commits.
- **Conventional Commits.** Use `feat(scope):`, `fix(scope):`, `docs(scope):`,
  etc. Release Please derives versions and the changelog from them.
- **Release tags.** Do not create `v*` tags by hand for normal feature
  releases; merge the release-please PR. Manual tags are only for
  hotfixes/prereleases. The nightly job also cuts patch tags when dependency
  ranges move (see below).
- **App version in the UI.** `kAppVersion` in
  [`app/lib/src/app_version.dart`](app/lib/src/app_version.dart) is shown on
  About and the map chip (and therefore on the website). Release Please keeps it
  in sync with `version.txt` and `app/pubspec.yaml` via the
  `# x-release-please-version` marker for feature releases; the nightly job
  bumps the same files for dependency patches.

## Branch model

| Branch | Role |
| --- | --- |
| `dev` | Default branch for features and improvements |
| `main` | Production. Releases and GHCR images land here |

- Open feature/fix PRs against **`dev`**.
- To release features: merge **`dev` into `main`**, then merge the
  release-please PR. Publishing the Release triggers
  `.github/workflows/release-publish.yml` for the GHCR web image. A tag alone
  does **not** publish an image.
- **Keep `dev` and `main` in sync.** The nightly dependency job commits to
  `main`, so it back-merges into `dev` in the same run. Without that, `dev`
  falls one commit further behind every night and the next promote conflicts
  on `pubspec.yaml` / lockfiles. To check:

  ```bash
  git fetch origin && git rev-list --count origin/dev..origin/main
  ```

  The merge step runs in a scratch worktree on purpose — checking `dev` out
  in the primary tree would leave the job on the wrong branch for later steps.

### Nightly minor dependency updates

`.github/workflows/nightly-minor-deps-release.yml` runs daily (~00:17 AEST)
on **`main`**:

1. `tools/update_minor_deps.py` raises caret ranges in `app/pubspec.yaml`,
   `tools/paluma_cli/pubspec.yaml` and `tools/basemap/package.json`
   (`npm-check-updates --target semver`: same major for 1.x+, same minor for
   0.x). Versions published in the last **3 days** are skipped (`--cooldown`).
2. Analyze / test / brand colour check when constraint files moved.
3. Patch-bump `version.txt`, `app/pubspec.yaml`, `kAppVersion` and
   `.release-please-manifest.json`, commit to `main`, create a GitHub Release
   pinned to the tested commit, then explicitly dispatch `release.yml` on its
   tag and `release-publish.yml` for GHCR `:latest`. `GITHUB_TOKEN` events do
   not start those workflows automatically.
4. Back-merge `main` → `dev` (fast-forward, else a merge commit in a scratch
   worktree, else open a `chore/sync-main-to-dev` PR).

Constraint files are the intentional edit. Lockfiles are only re-resolved so
CI can still install. Branch protection on `main` / `dev` needs a bypass for
Actions if pushes from `GITHUB_TOKEN` are blocked.

Only `release-publish.yml` pushes the web image. The nightly workflow invokes
it explicitly for dependency patches; feature releases use the release event.

- `release-publish.yml` — on `release: published` (plus `workflow_dispatch`
  with a `tag` input to re-publish an existing release). Feature releases from
  release-please use the same path.

Manual dry run from the repo root:

```sh
python tools/update_minor_deps.py --dry-run
```

## Before opening a pull request

1. Run the relevant format, analyze and test commands above.
2. For content changes, validate and confirm the generated bundle diff is
   committed.
3. For icon/splash/store changes, run `tool/check_generated_icons.sh` and inspect
   the 16, 24 and 48 px outputs.
4. For UI changes, check light, dark and sunlight modes and large text.
5. Link the issue and explain the user-visible change; include screenshots for
   UI work.

## Findings to preserve from the October 2026 work

Read the linked records before repeating research or changing the release
pipeline. These are evidence and implementation limits, not a claim that every
related GitHub issue is finished. Recheck live GitHub state before acting on PRs,
releases, credentials or deployments.

### History, photographs and permissions

- Start with [the POI research inventory](content/research/paluma-history.md),
  [source permissions](content/research/source-permissions.md) and
  [photo catalogue](content/photos/catalogue.json). The first pass added history
  or regional context to 12 of 52 existing POIs and five photographs. Other
  entries still need research; do not imply all sites are documented.
- Luen supplied permission for Linda Venn's book wording/photographs and
  Wanderstories wording/information/photographs. He also confirmed permission
  from Wilfred Karnoll for Townsville Bushwalking Club information. Preserve the
  exact scope and credits in the permission record. These permissions do not
  establish a public-domain or Creative Commons licence for onward reuse, and
  the club information permission must not be broadened to club photographs.
- The book uses **Gard**; existing `gardes-*` IDs remain stable. Printed book
  pages are two less than PDF page numbers. The council download may fail;
  the research inventory links a community-hosted reading copy.
- Shay's was a guesthouse in the researched accounts; a licensed hotel has not
  been established. The club reports date from 1965/1976. They do not establish
  today's surviving trees, structures, access rights or track conditions.
- Do not substitute nearby sites: Johnstone's hut is not Garde's hut, Cavill's
  battery is not Gards' Battery, and area history does not verify the exact
  location of either Witt's marker. Preserve coordinates and `unverified`
  provenance until new evidence supports a change.
- Photo files need offline captions, source/collection credits and permission
  text. Keep source image details, hashes and extraction/crop records in the
  catalogue. Every referenced file/POI pair needs a catalogue entry with the
  exact SHA-256 and a local permission-record link; content validation checks
  these before bundling. This does not replace reviewing permission scope.
  The bundler copies referenced photos; never fix a missing asset by
  making its display depend on a remote URL. See
  [the photo QA record](docs/qa/poi-history/README.md).

### Release and update pitfalls

- Set Release Please's **`target-branch: main` explicitly**. Its action defaults
  to the repository default branch (`dev`), even when triggered by a push to
  `main`. Run 40886443399 completed successfully but read `dev` and produced no
  release; [PR #116](https://github.com/Luen/Paluma-Trails/pull/116) records the fix.
- `GITHUB_TOKEN`-created tags/releases do not automatically trigger downstream
  push/release workflows. Preserve the explicit workflow-dispatch fallback for
  artifact builds and GHCR publication. With no release PAT, repository policy
  may also prohibit Actions from opening release PRs: use the official Release
  Please CLI/library against `main` with the maintainer's authenticated session,
  rather than weakening repository permissions or hand-tagging a normal release.
- A successful version PR or an empty GitHub Release is not release completion.
  Verify the `Release` and `Publish release image` runs, downloadable AAB,
  per-ABI APKs, web archive, checksums and expected GHCR tags. Signing secrets
  absent means debug-signed sideload builds, not Play/TestFlight publication.
- Bundles currently ship inside app/web assets. Independent bundle download,
  validated activation and preference-aware weekly updates remain #17/#87.
  Do not describe packaged-content loading as a completed background updater.
  See [the content release runbook](docs/content-releases.md).

### Remaining verification and external dependencies

- Use [the field-test protocol](docs/field-testing.md) and
  [report template](docs/field-test-report.md). Component previews, widget tests
  and CI do not establish real GPS, battery behaviour, TalkBack/VoiceOver on
  devices, track accessibility or verified reception points (#60).
- Check current blockers before implementing services: report recipients and
  fields (#31), privacy/retention (#36), and the proposed intake decision in
  ADR 0004 precede a live reporting backend. Store accounts/signing (#52/#66),
  web hosting (#69) and physical sign permission (#27/#44) require owner or
  external setup; do not invent approvals or silently contact third parties.
- For QPWS alerts, the owner's `WS-Maps` repo has `scrapers/qpwsAlerts.js` and
  emits `QueenslandNationalParkAlerts.geojson`. QPWS `longLat` values may be
  latitude/longitude; GeoJSON must be longitude/latitude. Historical/cached
  alerts must not be presented as current or as evidence a park is open.
- The owner confirmed BOM data permission in #37. On 2026-10-29, the
  `api.weather.bom.gov.au` location-search response used by WS-Maps nevertheless
  carried an explicit restriction on API reuse. Do not assume the data
  permission covers that API. BOM's published product documentation lists QLD
  Précis XML `IDQ11295`; the inspected feed had Ingham/Townsville but no Paluma
  location. Do not silently label a nearby town's forecast as Paluma. Recheck
  [BOM data services](https://www.bom.gov.au/resources/data-services), the
  authorised product and attribution/caching scope before choosing #39's feed.

### Follow-up work already opened

Before opening duplicate work, inspect the current state of
[source links #112](https://github.com/Luen/Paluma-Trails/pull/112),
[accessibility #114](https://github.com/Luen/Paluma-Trails/pull/114),
[MVP scope #115](https://github.com/Luen/Paluma-Trails/pull/115),
[release target fix #116](https://github.com/Luen/Paluma-Trails/pull/116),
[BOM investigation #118](https://github.com/Luen/Paluma-Trails/pull/118) and
[QR contract #119](https://github.com/Luen/Paluma-Trails/pull/119).
Some are partial work on larger issues; their existence does not establish that
the issue's acceptance criteria or external prerequisites are satisfied.
