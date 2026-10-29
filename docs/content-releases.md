# Content updates and releases

This is the maintainer runbook for #54. A correction to a POI, hazard, track or
junction starts in `content/data/paluma/`, passes review on `dev`, and reaches
walkers in a new app/web release. The packaged bundle is the current delivery
mechanism. Installing a newer app is required to update native offline content;
there is no independent bundle downloader yet (#17, #87).

## Prepare a change

1. Start a short-lived `content/…` or `fix/…` branch from the latest `dev`.
2. Edit the source files described in [the content model](content-model.md).
   Keep existing IDs and QR IDs stable. Include evidence for new facts in the
   POI's `sources` and record source provenance/licensing in `sources.json`.
   Keep uncertain imported content marked `unverified`; a recent edit is not
   field verification. Do not add unsupported safety or reception claims.
3. Set `park.json`'s `updated` to the content revision date (`YYYY-MM-DD`,
   Australia/Brisbane). This dates the content revision, not every source fact.
4. If tracks or junctions changed, regenerate `segments.json` with `content
   graph`. Check the graph diff for missing connections or implausible distances.
   Keep estimated-time wording. A POI-only edit does not require a graph rebuild.
5. Rebuild the bundle and commit it with the source changes. Never edit
   `app/assets/bundle/content/` or the manifest by hand.

From the repository root, after installing the Dart/Flutter SDK:

```sh
(cd tools/paluma_cli && dart pub get)
# Only for track or junction changes:
dart run tools/paluma_cli/bin/paluma_cli.dart content graph
# For every content revision:
dart run tools/paluma_cli/bin/paluma_cli.dart content validate
dart run tools/paluma_cli/bin/paluma_cli.dart bundle build
```

For a basemap refresh, use [the basemap pipeline](../tools/basemap/README.md)
first and update its build-date provenance in `sources.json`. Basemap inputs
live under `content/basemap/`; commit both those inputs and the rebuilt assets.
Photos need permission and credits, plus offline packaging/rendering support;
a `photos` entry alone does not make an image available in the current app.

## Review and verify

The builder validates the source before writing the bundle. Its manifest lists
`schema_version`, `bundle_version`, every file's size and SHA-256, and total
size. `bundle_version` combines `park.updated` and a digest of the bundle files.
It is deterministic: rebuilding unchanged inputs must produce identical bytes.
The content version is separate from the app's semantic release version.

Reproduce CI from the repository root (choose a fresh scratch output path):

```sh
(cd tools/paluma_cli && dart format --output=none --set-exit-if-changed . && dart analyze && dart test)
dart run tools/paluma_cli/bin/paluma_cli.dart content validate
dart run tools/paluma_cli/bin/paluma_cli.dart bundle build --out /tmp/paluma-review-bundle
diff -r /tmp/paluma-review-bundle app/assets/bundle
(cd app && flutter pub get && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test)
```

`bundle build --out` replaces its destination directory. Never point it at the
repository root or a directory containing work you need to keep.

Open a PR to `dev` with the source/evidence, generated diff, bundle version and
a short description of what walkers will see. CI checks the generated bundle
against a clean rebuild. In the app, inspect the changed feature with networking
disabled, including any revised safety copy. Geometry changes also need a route
and junction check; follow the device checks in [the location guide](location.md#device-checks).
A maintainer reviews the facts as well as CI before squash-merging.

## Deliver and confirm

Follow [the release runbook](release.md): promote `dev` to `main`, review and
merge the Release Please version PR, and wait for the release build. Use a
Conventional Commit such as `fix(content): correct a POI location` so a content
fix participates in versioning. Do not create normal release tags by hand.

- **Android/iOS:** build assets include the committed bundle. Current automated
  releases provide Android artifacts; iOS/store delivery depends on #66/#65.
  The installed app must be updated before it receives the content revision.
- **Native startup:** files are copied to Application Support under
  `bundle/<bundle_version>/`. A completion marker is written after copying;
  incomplete copies retry on launch, and old directories are pruned after a
  successful copy. The loader caches the loaded bundle for the process lifetime.
- **Web:** deploy the new web build/container using
  [the hosting runbook](web-deployment.md). An already open page can retain its
  loaded bundle. Reload online, verify the version, then test offline; release
  publication alone does not update a server or an offline browser cache.

Record the git revision, release version, bundle version and verification result
in the release/PR. Check the bundle version shown on the map, the corrected POI
or junction, and offline map labels after installing/reloading the new build.
Do not describe the revision date as a live conditions or closures feed.

## Correct a bad release

Revert the faulty source change on a fresh branch from `dev`, regenerate any
changed graph and the bundle, validate, review, and cut a new patch release.
Use a current revision date so the corrective revision is identifiable. Do not
rewrite an existing tag or replace assets under a published version. Native
users need the corrective app update; web users need the deployment and reload.
If the issue affects safety, describe the affected content and versions plainly
in the corrective release notes and escalate to the maintainer immediately.

## Independent downloads remain follow-up work

ADR 0004 records the intended GitHub Release hosting for independent bundles.
The current release workflow does not publish a standalone bundle archive and
the loader reads packaged assets only. Before enabling #17/#87, add versioned
publication and a client that validates schema compatibility, paths, file sizes
and hashes, stages the entire download, switches only after validation, and
keeps a working offline copy on interruption or failure. Honor Wi-Fi/mobile
preferences and show last-updated status. Manifest hashes are metadata today;
the packaged loader does not verify them at runtime. Do not tell walkers that a
weekly background update exists until that path is implemented and tested.
