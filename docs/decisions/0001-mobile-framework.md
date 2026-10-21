# ADR 0001: Mobile framework — Flutter

- **Status:** Accepted
- **Date:** 2026-10-16
- **Issues:** #3, #2

## Context

Issue #3 asks us to pick between Flutter, React Native and Kotlin Multiplatform for
the mobile app. The evaluation criteria were offline map support (MapLibre SDKs),
QR scanning, background sync, maintainer familiarity and build/release effort.

Additional context:

- The maintainer already has Flutter installed and working (3.47.x stable).
- Issue #62 (CI/CD) assumes Flutter and a `dev` branch, so the release pipeline
  was already being designed around it.
- The website question (#4) is easier to answer if the web build can share the
  app code.

## Decision

Use **Flutter** for the mobile app, targeting Android and iOS first, with the
same codebase compiled to web for the map (`flutter build web`).

## Rationale

- **Offline maps:** `maplibre_gl` (flutter-maplibre-gl) 0.27.x supports MapLibre
  Native on Android/iOS and maplibre-gl-js on web from one Dart API, including
  vector, raster, GeoJSON and PMTiles sources. Native offline region downloads
  are supported on Android and iOS.
- **One codebase, three targets:** Android, iOS and web. React Native has no
  first-party web target and Kotlin Multiplatform's web story is not mature.
- **QR scanning:** mature plugins exist (`mobile_scanner`), including on web.
- **Background sync:** solid plugin ecosystem (`workmanager`, `flutter_local_notifications`)
  and the offline queue is plain Dart/JSON, so it is testable without platform code.
- **Maintainer familiarity and CI:** the maintainer is set up for Flutter and the
  planned CI/CD (see #62) is already Flutter-shaped.
- **Testability:** the content model, graph maths and offline queue can be pure
  Dart, unit tested in CI on Linux without simulators.

## Alternatives considered

| Option | Verdict |
| --- | --- |
| React Native | Weakest option for offline vector maps plus web sharing; would need a separate web codebase. |
| Kotlin Multiplatform | Excellent native map performance, but web support is immature (the planning map, #22, would need a separate site) and it adds a second toolchain for the content tooling. |
| Native Android + Swift separately | Rejected: two apps to maintain for a volunteer-scale project. |

## Consequences

- The web build is a Flutter web app (a PWA). See ADR 0002 for the website strategy.
- Map rendering is delegated to `maplibre_gl`; we do not reimplement tile rendering.
- Store builds require the standard Flutter release setup (epic #62, #65).
- Content tooling (`tools/`) is written in Dart so the project has one language
  for CI to install.
