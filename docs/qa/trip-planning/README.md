# Trip-planning QA

Reviewed 30 October 2026 against bundle `2026-10-30-04c0da3b`.

- `light-dark.png`: real bundled notes in both themes, 360 px previews.
- `sunlight-large.png`: sunlight and 2× text, with short tab labels.
- `gallery-credits.png`: light/dark photographs with captions, credits and
  permission statements, plus the offline place-history action.
- `gallery-large.png`: sunlight photograph and 2× text caption/credit wrapping.
- `plan.png`: final release web build, bounded 800 px reading column.
- `gallery.png`: final release web gallery, credited historic image and Garde's
  Lookout context image.

Actual browser flow: map → About → trip hub → Photos → credited photograph →
place history. No GPS permission, external source/booking action or network
photo was used. Source labels remain readable without opening a website.

The first large-text regression found an existing POI-header overflow when
opening history. Moving the Unverified chip below its title row fixed it; the
320 px, 2× test now covers that full navigation path.

Analysis, 192 app tests, 36 CLI tests and release web build passed. After the
desktop width adjustment, analysis and the seven hub tests were repeated.
Content validation and byte-for-byte regenerated bundle/map checks passed.
The four previews use the app assets/fonts through the ignored scaffold setup
documented in `docs/trip-planning.md`. These are rendering checks, not field
verification of facilities, reception, access or present conditions.
