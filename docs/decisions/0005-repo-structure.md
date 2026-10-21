# ADR 0005: Monorepo layout

- **Status:** Accepted
- **Date:** 2026-10-16
- **Issues:** #6, #2

## Context

Issue #6 asks for a monorepo layout (`content/`, `app/`, `web/`, `docs/`), lint/test
CI, CONTRIBUTING.md and issue templates. The app and the website are one Flutter
codebase (ADR 0002), so a separate `web/` package is not needed yet.

## Decision

```
app/       Flutter application (Android, iOS, web)
  assets/bundle/   the packaged offline bundle the app loads at runtime
content/   source of truth for trail content (JSON/GeoJSON + schema)
  data/paluma/     the park's data
  schema/          JSON Schema for all content files
  sources/         raw imports kept for provenance (uMap export, GPX)
tools/     Dart CLI: content import, validation, graph maths, bundle builder
docs/      roadmap, content model, architecture decision records
.github/   CI workflows, issue/PR templates
```

Rules:

- `content/data/**` is hand-editable and reviewed by humans. Everything in
  `app/assets/bundle/content/**` is **generated** by `tools/` and must not be
  edited by hand (CI checks it is up to date).
- `app/assets/bundle/basemap/**` holds external, reproducible assets (PMTiles
  extract, style, fonts, sprites). They are committed because they are small
  (≈2.5 MB) and make builds and first-run offline work without network access.
- The Dart CLI is the single entry point for content work:
  `dart run tools/paluma_cli/bin/paluma_cli.dart <command>`.

## Consequences

- One CI job can validate content, run the builder, check it is up to date, then
  analyze/test/build the Flutter app.
- Non-developer content editing (#13) can be layered on top of `content/data`
  later (git-backed CMS) without moving files.
