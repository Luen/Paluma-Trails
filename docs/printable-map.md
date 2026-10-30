# Printable planning map

On the web app, open **About → Walking guides → Printable planning map**.
The standalone `printable-map.html` page has **Print / save as PDF**, using
the browser's print dialogue. Choose A4 portrait and normal/default scaling;
turn off the browser's optional page headers/footers if they obscure the page.
Print the overview/detail pages and any reference tables you need.

The page contains the current track geometry, numbered junctions, an enlarged
village junction map, selected researched POIs, an approximate scale bar and
north arrow. Reference tables contain all junction coordinates and individual
segment distances with **estimated** walking times. POI P-numbers are local to
the printed content revision; stable POI IDs are listed separately.

This is a planning overview without terrain, contours, a road basemap or current
closures. Content remains unverified. It is not a substitute for an appropriate
navigation map or current official advice. The selected POIs are those with
research source records, not every POI in the app.

## Offline use

Save the HTML page itself or save/print a PDF while preparing for the walk.
The HTML embeds the SVG maps and styles and makes no external asset requests.
Reading a saved copy needs no web fonts, scripts or connection. Only the print
button uses JavaScript, and the browser's own Print menu is an alternative.
The interactive-map link needs the app/website to be available separately.
A fresh visit to the website still needs a connection; this does not implement
automatic bundle downloads or background updating (#17/#87).

## Regeneration

From the repository root, after editing source content or map palette:

```sh
dart run tools/paluma_cli/bin/paluma_cli.dart content print-map
```

The command validates source content and writes `app/web/printable-map.html`.
Use `--out /tmp/printable-map.html` for a comparison without overwriting the
checked-in output. CI regenerates and diffs the page. Flutter copies it into
the web build, release tarball and web container; no PDF renderer is needed in
the app or CI. The displayed update date comes from `park.json`; the revision
is a deterministic hash of the five source content files.

The generator reads line colours from `MapPalette`, uses dashed informal tracks,
and retains Wanderstories attribution. It never fetches a basemap or silently
adds elevation to the walking-time estimates.
