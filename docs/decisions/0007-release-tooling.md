# ADR 0007: Release tooling for store delivery

- **Status:** Accepted
- **Date:** 2026-10-20
- **Issues:** #67, #65, #66, #62

## Context

The Release workflow (`.github/workflows/release.yml`) already builds the AAB,
per-ABI APKs and the web bundle in plain GitHub Actions on `v*` tags, and
publishes the web image to GHCR. Store uploads still need a decision: in-repo
fastlane, a third-party action, or Codemagic. Credentials are tracked in #66 and
are not configured yet.

## Decision

- **Build and release orchestration stays in plain GitHub Actions.** No
  Codemagic, and no wrapper action around fastlane.
- **Store delivery uses fastlane lanes kept in the repository.**
  - Android: `supply` uploads the release AAB to the Play **internal** track.
  - iOS: `match` + `build_app` + `upload_to_testflight` on a macOS runner,
    using the App Store Connect API key and match secrets from #66.
- **Store jobs are opt-in.** They only run on tags when the relevant secrets
  exist, inside a GitHub `production` environment with required reviewers.
  Without Android signing secrets the workflow keeps publishing debug-signed
  sideload APKs as it does today.
- **Tags remain the release trigger.** The version name comes from the tag; the
  build number is `github.run_number`. release-please automation is still
  tracked in #65 and does not change the delivery tool.

## Rationale

- Fastlane is the path documented by Flutter's continuous-delivery guide and
  covers both stores, including `match` and TestFlight, in one tool.
- Keeping the lanes in-repo makes a failed upload reproducible locally with the
  same commands, and keeps credentials in GitHub rather than a second CI
  vendor.
- The build half is already working with plain Actions; replacing it with a
  third-party service would add migration risk for no gain.
- A single-store action (such as `r0adkll/upload-google-play`) would still need
  fastlane for iOS, leaving two delivery mechanisms to learn and maintain.

## Alternatives considered

- **MTtankkeo/flutter-fastlane-action**: a thin wrapper that hides the fastlane
  setup. Rejected because it adds a dependency without removing the need to
  understand the lanes.
- **Codemagic**: a hosted CI with a free macOS allowance. Rejected because the
  free-tier terms would need rechecking, secrets would live outside GitHub, and
  debug builds are already cheap on GitHub-hosted Linux runners.
- **Direct Play API action + fastlane for iOS**: fewer moving parts on Android,
  but two delivery tools and two credential formats. Reusing fastlane is
  simpler once the iOS lane exists.

## Consequences

- `android/` and `ios/` will gain `Fastfile`/`Appfile` configuration when #66
  unblocks store publishing; macOS minutes are only spent on release tags.
- The first Play upload must be done manually to create the app record. Later
  uploads can use the internal track, with promotion to production manual.
- Losing the upload keystore is still serious even with Play App Signing; the
  backup instructions in #66 remain mandatory.
- Until signing is configured, releases remain debug-signed sideload builds;
  the existing GitHub Release path is unaffected.
