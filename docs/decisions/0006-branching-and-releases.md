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
  branches), and merging a promotion to `main` triggers the release workflow.
- **CI runs on every PR** to `dev` and `main`, and on pushes to `dev`: format,
  analyze, test, content validation, bundle freshness check, web build, debug APK.
- **iOS builds are skipped on PRs** (macOS runners bill at 10×) and run as part of
  releases only.
- **Versions** come from git tags and conventional commit messages
  (`release-please` or equivalent), producing `v<major>.<minor>.<patch>` and a
  monotonically increasing build number (`github.run_number`).
- Branch protection on `main` requires a PR and green CI.

## Rationale

- Matches the model the maintainer already uses on other projects (issue #62
  references the Morphe patches template flow).
- Keeps `main` always releasable; testers can install builds from `dev` releases.
- The release workflow is deliberately plain (Flutter CLI + fastlane) so it can be
  debugged locally; no proprietary CI service is required. Issue #67 keeps the
  fastlane vs. third-party action vs. Codemagic decision open until we wire store
  uploads.

## Consequences

- `dev` must be made the default branch in GitHub settings.
- Store upload credentials (issue #66) are only needed once store publishing
  starts; until then the release workflow produces artifacts on the GitHub Release.
- A release-please (or similar) workflow must be added with the release workflow
  (#65).
