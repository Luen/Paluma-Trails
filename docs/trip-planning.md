# Trip planning and photographs

Open **About → Trip planning and photos · offline**. The Plan tab contains dated,
QPWS-sourced access, camping and facilities notes. Text and source labels work
offline. “Read online” opens an external source or booking website only after
a tap; the app does not make bookings or fetch conditions here.

The Photos tab collects every bundled POI photograph, grouped by place and sorted
by place name. Captions, credits and permission statements remain visible.
“Read place history” opens the existing offline POI sheet. Historic photographs
and undated place context never imply present track conditions.

Edit `content/data/paluma/trip-planning.json`, validate it, rebuild the bundle and
regenerate the printable map. The asset is optional for older schema-1 bundles;
if absent, the hub explains the missing notes and still offers the photo tab.
A manifest-declared but unreadable file is a bundle error, not silently ignored.

Source scope and unresolved contradictions are recorded in
[the research notes](../content/research/trip-planning.md). The first pass covers
national-park camping; it is not an inventory of all district accommodation.
Current alerts (#40), weather (#39), independent updates (#17/#87), field-verified
reception (#60) and track accessibility (#53) remain separate work.

Four component previews use the real bundle in light, dark, sunlight and 2× text.
Widget tests exercise the actual notes, all five credited photos, navigation to
POI history, older-bundle/empty-gallery states and entry without GPS.

The Flutter-generated `.widget_preview/` scaffold does not automatically declare
the application's root assets. For local visual QA, copy the app pubspec's
`flutter.assets` and `flutter.fonts` declarations into that ignored scaffold and
link its `assets/` directory to `../assets`, then restart the preview server.
Keep this local setup out of git. Without it the preview explains the missing
asset; do not mistake that for a production bundle-loading failure.
