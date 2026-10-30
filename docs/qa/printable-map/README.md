# Printable-map review

The actual generated HTML was inspected in the in-app browser. The initial
overview crowded the central junctions; the final layout separates a park-wide
overview and an enlarged village junction map. These are planning diagrams
without a terrain basemap or live closures.

The HTML's A4 print CSS was rendered with WeasyPrint 70 for visual review.
All six PDF pages were rasterised and inspected: two map sheets, segment
distances/estimated times, all junction coordinates and the selected POI index.
Table headers repeat across pages and rows are not split. The PDF contains the
unverified notice, update date/revision and Wanderstories credit.

- [Overview print render](overview.png)
- [Village detail print render](detail.png)

The first PDF render exposed unsupported SVG `paint-order` hiding labels;
the generator now uses explicit halo/fill text layers. The scale/footer also
has an opaque paper background to keep crossing tracks from obscuring it.

Native browser print-dialog automation was unavailable, so an end-to-end
Chrome/Safari Save as PDF interaction is not claimed. Other browsers may
paginate reference tables differently. No PDF rendering dependency is added
to the product or CI; the browser Print menu remains the normal export path.

Content-tool tests verify projection orientation/scale, complete source
coverage, escaping, deterministic revisions and no external asset dependencies.
App analysis, 173 widget/unit tests and the release web build pass. The About
link uses the existing source-link component, already checked in light, dark,
sunlight and large-text previews.
