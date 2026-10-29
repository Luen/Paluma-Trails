# Content model

Safety guidance may include optional `sources` entries with an offline-readable
label and an HTTPS URL. The app displays them as explicit online source links;
the guidance itself stays bundled. Older bundles without these references still
decode. Emergency-contact changes should cite current official sources; see
[the research record](../content/research/emergency-contact-guidance.md).

Everything a walker sees on the map, in junction cards and on POI pages comes from
`content/data/paluma/`. The app never invents content at runtime; it renders exactly
what the bundle contains, so a content fix is a data change plus a release.

## What the app shows

- **Tracks** — the walking network: polylines with a name and a class.
- **Junctions** — the numbered markers physically on the tracks (1–42 on the
  Paluma network). These are the anchor points for "what's ahead" decisions.
- **Segments** — the stretch of track between two junctions, with distance and an
  estimated walking time. **Generated** from tracks + junctions.
- **POIs** — everything else worth stopping for: waterfalls, lookouts, mine ruins,
  huts, campsites. Some have QR codes on the track; all are tappable on the map.
- **Safety guidance** — plain, offline advice for the safety page: what to do in
  an emergency, what to carry and how to think about reception.

## Files

| File | Edited by hand? | Purpose |
| --- | --- | --- |
| `park.json` | yes | Park identity, bounds, emergency info, attributions |
| `tracks.geojson` | yes (or `import-umap`) | Track polylines |
| `junctions.json` | yes | Numbered junctions and their notes |
| `pois.json` | yes | Points of interest, text, sources |
| `safety.json` | yes | Offline safety guidance and emergency steps |
| `trip-planning.json` | yes | Dated pre-visit notes with per-section official references |
| `segments.json` | no — generated | Junction-to-junction graph with distances/times |
| `sources.json` | yes | Provenance and licences of each data source |

## Conventions

Trip planning is bundled planning information, not a live conditions service.
Each section needs non-empty paragraphs and HTTPS source links, with an explicit
check date. Older bundles without the optional asset show an explanatory fallback
and retain their gallery. See [trip planning](trip-planning.md).

- **IDs** are lowercase slugs: `gardes-clearing`, `pbr-track`, `j7`. They are
  permanent — QR codes encode them (#25), so renaming an id breaks a sign on a
  track. Add new ids rather than reusing old ones.
- **Coordinates** are WGS84. GeoJSON uses `[longitude, latitude]`; JSON objects
  use `{"lat": …, "lon": …}`.
- **Distances** in metres, times in whole minutes.
- Every POI carries `sources`. A claim without a source does not belong in the
  content.

## Walking-time estimates

Times are computed by `tools/paluma_cli` using Naismith's rule on the flat:

```
minutes = ceil(distance_km / pace_kmh * 60 / 5) * 5     (rounded up to 5 min)
```

with a default pace of **4.0 km/h** for a maintained walking track. Elevation is
not yet in the data (issue #14 will add DEM-derived profiles), so the estimate is
deliberately conservative and is labelled in the app as:

> Estimate — flat-terrain pace, elevation not included.

When elevation lands, segments gain `ascent_m` and `descent_m`, both measured
walking `from` → `to`; walking the other way, the app shows `descent_m` as the
climb. The estimate then becomes `naismith-v2` (add 1 minute per 10 m of ascent),
which makes walk times directional too. Both the method and the pace are recorded
on each segment so the app can be honest about what it knows.

For review, delivery and recovery, follow [Content releases](content-releases.md).

## Adding a new POI

1. Find it on the map (or in the sources) and note the coordinates.
2. Add it to `pois.json` with a category and at least one source.
3. `dart run tools/paluma_cli/bin/paluma_cli.dart content validate`
4. `dart run tools/paluma_cli/bin/paluma_cli.dart bundle build`
5. Commit both the source change and the rebuilt bundle.

The app groups categories for the map's display toggles (water, lookouts,
camping, history, other). A new category also needs a home in
`app/lib/src/map/poi_groups.dart`; `hazard` is deliberately left ungrouped so a
warning cannot be hidden. Categories the app does not know about still draw, so
a bundle update can never silently lose a marker.

## Provenance

The initial track network was imported from the project's own uMap export
(`content/sources/umap-264617.geojson`) which is maintained by the Wanderstories
author and volunteers, currently the de-facto record of the Paluma tracks. The raw
export is kept in `content/sources/` and the import is reproducible via
`content import-umap`.

## Photographs

POI `photos` entries name a local file in `content/photos/` and require a caption,
credit and licence/permission statement. Filenames use lowercase letters,
numbers and hyphens, with a `.jpg`, `.jpeg`, `.png` or `.webp` extension; nested
paths and remote image URLs are rejected. Validation fails on missing images or
missing attribution. Keep permissions and extraction provenance beside the
original files; the Paluma history images have a [permission record](../content/photos/README.md).

`bundle build` copies only referenced images into `app/assets/bundle/photos/`
and includes their byte sizes and SHA-256 hashes in the manifest. The app shows
photos, captions and credits from bundled assets, without network requests.
A missing/unreadable image leaves the historical text, caption and attribution
available with an explanatory message. Run a fresh build after adding an image
so Flutter includes the asset, and check light/dark/sunlight modes and large text.
