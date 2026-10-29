# ADR 0008: Content editing through reviewed requests and source JSON

- **Status:** Accepted
- **Date:** 2026-10-29
- **Issues:** #13, #8

## Context

The content source is JSON/GeoJSON in git, with schemas and a deterministic
bundler. Contributors may have local knowledge without a Dart/Flutter setup.
An editor must keep facts, licences, stable IDs and generated assets reviewable.
The current workflow does not have a CMS, editor service or spreadsheet importer.

## Decision

Use a structured **Content correction** GitHub issue form as the entry point
for non-developers. Maintainers turn accepted requests into small source JSON
PRs, regenerate the bundle and deliver it in an app/web release. Contributors
comfortable with JSON can submit source edits directly to `dev`; maintainers
help with generated files before merge. The contributor does not need an SDK
or a runtime service beyond GitHub.

The form asks for the affected place/ID, current and proposed content, evidence,
observation date/uncertainty and image permissions when applicable. No request
bypasses source review, schema validation or bundle freshness checks. Existing
IDs/QR IDs stay stable; the current source and generated-asset contracts remain
as described in ADR 0005.

## Alternatives

- **Direct JSON editing only:** minimal tooling but excludes useful contributions
  from people unfamiliar with git, JSON or local builds. Retained as an option.
- **Git-backed CMS (Decap/Tina):** could provide purpose-built forms, but adds
  configuration, authentication and schema maintenance before contribution
  volume demonstrates that need. Revisit if the request/maintainer queue becomes
  a bottleneck.
- **Spreadsheet import:** familiar for bulk editing, but needs an importer and
  rules for nested citations, geometry, IDs and conflicts. Defer until there is
  a demonstrated bulk-editing workflow and a named owner for it.

## Consequences

Contributors need a GitHub account and maintainers still own validation and
publication. Review capacity limits throughput; the form does not promise a
response time or deployment. No new hosting, credentials or dependencies are
needed. [The contributor guide](../content-editing.md) explains the handoff and
current limits. Facts, photo rights and field accuracy still need human review.
