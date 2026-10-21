# ADR 0006: Branching model and release flow

- **Status:** Accepted
- **Date:** 2026-10-16
- **Issues:** #63, #62, #64, #65

## Context

Issue #63 proposes `dev` for work/testing and `main` for releases, with a
dev → main promotion PR triggering a release. Issue #65 sketches a release
workflow (AAB/APK + IPA + web, tag, GitHub Release, store uploads).

## Decision

- **`dev` is the default branch.** All work lands there via pull requests from
  short-lived feature branches (`feat/…`, `fix/…`, `docs/…`, `chore/…`).
- **`main` is release-only.** It only receives PRs promoted from `dev` (or hotfix
  branches). A promotion does not release by itself: pushing a `v*` tag on the
  promotion commit starts the Release workflow. Manual runs build artifacts
  without publishing.
- **CI runs on every PR** to `dev` and `main`, and on pushes to `dev`: format,
  analyze, test, content validation, bundle freshness check, web build, debug APK.
- **iOS builds are skipped on PRs** (macOS runners bill at 10×) and run as part of
  releases only.
- **Versions** come from `v*` tags for now: the tag's semantic version becomes
  the version name and `github.run_number` the version code. release-please (or
  equivalent) automation is still tracked in #65.
- Branch protection on `main` requires a PR and green CI.

## Rationale

- Matches the model the maintainer already uses on other projects (issue #62
  references the Morphe patches template flow).
- Keeps `main` always releasable; testers can install builds from `dev` releases.
- The release workflow is deliberately plain (Flutter CLI + fastlane for store
  delivery) so it can be debugged locally; no proprietary CI service is required.
  The store-delivery choice is recorded in ADR 0007.

## Consequences

- `dev` must be made the default branch in GitHub settings.
- Store upload credentials (issue #66) are only needed once store publishing
  starts; until then the release workflow produces artifacts on the GitHub Release.
- A release-please (or similar) workflow must be added with the release workflow
  (#65).

## Amendments

- **2026-10-20:** Releases are tag-driven for now (`v*` tag, or a manual run that
  only builds artifacts). The earlier "merge to `main` triggers a release" step
  waits for release-please in #65. Store delivery uses in-repo fastlane lanes
  (ADR 0007).
- **2026-10-21:** Versioning and changelog automation use release-please on
  `main` (#65). A promotion to `main` opens a release PR; merging that PR
  creates the `v*` tag and GitHub Release, which still triggers the Release
  workflow. Manual tags remain supported for hotfixes and prereleases.
  Release Please uses a `RELEASE_PLEASE_TOKEN` PAT because tags created with
  `GITHUB_TOKEN` do not trigger workflows.
