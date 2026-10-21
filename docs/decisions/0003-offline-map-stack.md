# ADR 0003: Offline map — MapLibre GL with a bundled vector PMTiles basemap

- **Status:** Accepted
- **Date:** 2026-10-16
- **Issues:** #16, #15, #17

## Context

Issue #16 asks us to choose the basemap and offline tile format. Requirements:

- Fully usable in flight mode after a download (#17).
- Small enough to download over mobile data if the user allows it.
- Good detail for walking tracks, with place/feature labels.
- No API keys and no per-tile costs.
- Must work on Android, iOS and web.

Paluma Range National Park covers roughly `146.05–146.33 E, 19.11–18.80 S`.

## Decision

Use **MapLibre GL** (`maplibre_gl` for Flutter) with a **vector PMTiles** basemap,
generated from the [Protomaps](https://protomaps.com) daily OSM build and served
as a single archive for the park extent. Trail overlays (tracks, junctions, POIs)
are drawn as GeoJSON layers from our own content bundle on top.

Concretely:

- Basemap archive: `pmtiles extract` from the Protomaps planet build,
  bbox `146.05,-19.11,146.33,-18.80`, zoom 0–15. **1.5 MB** for the whole park.
- Style: generated from `@protomaps/basemaps` (light theme), vendored into
  `app/assets/bundle/basemap/` together with Latin-range fonts (Noto Sans
  Regular/Medium/Italic) and sprites so labels render offline.
- On device: the PMTiles asset is copied to the app support directory on first
  run and loaded with `pmtiles://file://…`. On web the same archive is fetched
  with HTTP range requests from the site origin.
- Attribution is carried in the style and in the app's About screen:
  map data © OpenStreetMap contributors (ODbL), basemap by Protomaps (ISC),
  fonts under the SIL Open Font License.

## Rationale

- **Size:** 1.5 MB for the park at z0–15 is small enough to commit to the repo and
  to ship in the app binary, which removes an entire class of "download failed"
  problems from the MVP. Raster MBTiles for the same coverage would be 10–100×
  larger.
- **Rendering:** MapLibre Native gives proper labels, rotation and pitch, and
  styling can be tuned for outdoor readability (#21) without regenerating tiles.
- **Offline:** PMTiles is a single file, so it is trivial to version, hash and
  update incrementally (the manifest in #12 lists its hash and size). Native
  offline regions can be added later for larger extracts (e.g. the whole of the
  Townsville region).
- **No vendor lock-in or keys:** Protomaps builds are open data over OSM; if the
  project later wants Queensland Government QTopo detail, the same pipeline can
  ingest a different source into the same PMTiles archive format.

## Alternatives considered

| Option | Verdict |
| --- | --- |
| flutter_map + raster MBTiles | Simplest to reason about, but raster only (larger downloads, flat labels, no rotation) and MBTiles needs SQLite (native only). |
| MapTiler / Mapbox vector tiles | Nice rendering, but requires an account, API keys and has usage limits that can break an offline-first free project. |
| QTopo / QSpatial raster tiles as the base | Best official Queensland detail; kept as a future enhancement once licensing for offline redistribution is confirmed (see #10, #16). |
| Bundling tiles in the app (~1.5 MB) vs download-on-first-run | We do both: the archive ships in the app for the MVP so first-run always works, and the same archive doubles as the downloadable bundle for incremental updates. |

## Risks

- Protomaps z0–15 is coarser than a street-level map when overzoomed past z16.
  Acceptable for tracks; note it in the UI ("map detail to z15, overzoomed").
- OSM coverage of informal tracks is incomplete. Our own track network (from the
  project's GPX/uMap data) is drawn on top, so this matters less.
