# Content

This directory is the source of truth for everything a walker sees.

```
content/
├── data/paluma/     # the park's content (hand-edited)
├── schema/          # JSON Schema for every content file, enforced in CI
├── sources/         # raw imports kept for provenance (uMap export, GPX)
└── basemap/         # external offline assets: PMTiles archive, style, fonts
```

## Rules

- `data/**` and `sources/**` are edited by humans and reviewed in PRs.
- `schema/**` is the contract. CI validates all data against it.
- `basemap/**` holds reproducible external assets. See
  [`tools/basemap/README.md`](../tools/basemap/README.md) for how each file is
  produced, and [`sources.json`](data/paluma/sources.json) for licences.
- The app does **not** read this directory. It reads `app/assets/bundle/**, which
  is generated from here by `tools/paluma_cli` (`bundle build`). Commit the
  regenerated bundle in the same PR.

See [docs/content-model.md](../docs/content-model.md) for the data model and
conventions.

## Licences

- **Licence for the project's own content (track notes, POI text) is not yet
  decided** — see issue #46. Until then, treat content as all rights reserved by
  its contributors.
- Third-party data and imagery keeps its own licence. Every source used in the
  content is listed in [`data/paluma/sources.json`](data/paluma/sources.json)
  with its licence and attribution requirements.
