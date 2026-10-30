# Simulated walk preview

Open **About → App → Preview a walk · simulated**, select a bundled track and
start the preview. The normal map and junction/water card follow that geometry
using simulated positions. The title and persistent controls identify the mode;
this is a planning/QA preview, not evidence of current track access or conditions.

- Pause/resume, restart or choose 20×, 40× or 80× preview speed. Acceleration
  changes playback, not the bundle's estimated walking times.
- The preview uses no GPS plugin or permission request. If a real walk is being
  tracked, that stream pauses before preview entry and resumes after exit.
  Its walked total is retained; an untracked gap is not added to the distance.
- Preview waypoints are unavailable and its waypoint store is memory-only.
  Emergency/About actions are excluded from the preview map, and the safety
  navigation method guards against passing simulated coordinates to it.
- Leaving the preview disposes the simulated stream/timer. Pausing, reaching
  the end or leaving the foreground stops playback; returning to the app needs
  an explicit Resume. Closing the preview returns to the previous screen.

`WalkSimulation` interpolates along existing WGS84 vertices, emits mock
`Position` values through the normal `LocationService` interface and supplies
heading/speed presence flags so the trail locator can determine “next”. It
neither downloads routes nor writes a walk history. Each preview is a single
recorded track polyline, not an automatically verified or connected multi-track
itinerary. Some tracks have no mapped junctions or water points beside them.

## Verification

Unit tests cover interpolation/corners/endpoints, duplicate/invalid geometry,
speed bounds, pause/restart, mock-driver consumption without platform plugins,
and preserving real walked totals across an explicit pause. Widget tests check
320 px/double-size text and separately labelled playback controls. The progress
indicator has its own semantics container so it cannot absorb the buttons.

See [the visual QA record](qa/walk-preview/README.md) for light/dark/sunlight/
large-text previews and browser observations. Real-device GPS pause/resume,
platform background behaviour and outdoor readability still need the
[field-test protocol](field-testing.md).
