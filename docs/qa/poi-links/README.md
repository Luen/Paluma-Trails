# POI launch QA — 30 October 2026

Release review of #130 found that URI resolution against `/poi/<id>` requested
the basemap below `/poi/assets/...` and the print page below `/poi/`. The current
deployment is at the origin root. Both now use a shared root-resource resolver;
its regression covers known/unknown POI paths, trailing slash, query, fragment
and a localhost port for PMTiles, fonts, sprites and the print page.

Analysis, all 202 app tests and release web build passed. `direct-link.png` shows
a fresh browser visit to `/poi/gardes-lookout`: the correct offline sheet opens
over a rendered basemap with place labels, without requesting GPS. Local QA
uses the same SPA fallback behavior as Caddy and supports byte-range responses;
the actual production Caddy image is separately smoke-tested in release CI.
That smoke test now checks the direct-path HTML fallback, its no-cache header
and the root PMTiles range response before publishing the image.

The launch docs now describe browser routing accurately. Native verified App
Links/Universal Links and prepared offline-browser cache coverage are still
separate work. A retained/redirected old origin is necessary for printed codes
when hosting moves. The initial-POI callback also checks `mounted` after async
map-layer setup, so a disposed screen cannot open a sheet.
