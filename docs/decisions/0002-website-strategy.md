# ADR 0002: Website — share the Flutter codebase (web build), static site later if needed

- **Status:** Accepted
- **Date:** 2026-10-16
- **Issues:** #4, #22, #68

## Context

Issue #4 asks whether the website is a separate site (Astro/SvelteKit reading the
same content JSON), a PWA, or Flutter web / RN web sharing app code.

The website has two jobs:

1. **Planning tool** — the map, junction distances and POIs before the trip (#22).
2. **Discovery / SEO** — people searching "Paluma walking tracks" need to find
   the project and the content pages.

## Decision

Ship the **Flutter web build of the same app** as the website first (served as a
PWA so the map works offline in a browser too). Keep the door open for a small
static marketing/SEO site later; if we add one it will read the same `content/`
JSON as the app, so there is still a single source of truth.

## Rationale

- The map is the main reason to visit the site; Flutter web gives us the exact
  same MapLibre map, junction cards and POI pages as the app for free.
- One codebase to maintain for a volunteer-scale project.
- The CI sketch in #64 already builds `flutter build web`, and #68 already assumes
  a Docker image of the Flutter web build.
- Content JSON in `content/` is the contract. Any future static site consumes the
  same files and the same JSON Schema.

## Consequences

- SEO for individual POI/track pages is weaker than a static site. Mitigation:
  publish each POI as a stable URL (`/poi/<id>`, see QR scheme #25) that renders a
  static HTML fallback with the POI text, and revisit a static site if search
  traffic matters.
- Flutter web first-load size is larger than a static site. The web build should
  stay code-split where practical and is cached by the PWA service worker.
- The Docker/Caddy deployment (#68, #69) hosts `build/web`.
