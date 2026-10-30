# Location, the next junction and water

The map can show where the walker is (blue dot, heading, accuracy circle), how
far the next junction is **along the track**, how far they have walked and where
the next water is. Everything works with the network off: the fixes come from
the device's own location provider and the distances from the offline bundle.

## Flow

An explicitly labelled [walk preview](walk-preview.md) uses a separate mock
location driver after the user starts it from About. It pauses an existing real
GPS stream and isolates simulated positions from saved waypoints and safety
screens. The flow below describes normal live tracking.

1. Nothing runs until the walker taps the locate button. The app then asks for
   permission (or explains how to fix a refusal, a switched-off location service
   or a failed stream) and starts listening for fixes. A stream failure stops
   tracking, says so on the card and lets the next tap start a fresh stream.
2. Each fix is handed to MapLibre through its `ManualLocationSource`, so the
   native puck and the Dart-side logic use the same data on Android, iOS and the
   web. Android reads location through the platform `LocationManager` (the
   AOSP fused provider on Android 12+), so the app never depends on Google Play
   Services at runtime.
3. Tapping the button while tracking toggles the camera follow. A pan stops the
   follow (on the web, where the manual puck reports no tracking dismissal, the
   camera's resting position is compared with the fix); tapping again jumps
   back to the walker at walking zoom.
4. `TrailLocator` snaps the fix to the nearest track polyline, works out the
   direction of travel from the GPS bearing (only when the walker is moving at
   least 0.7 m/s) and measures the remaining distance **along** the polyline to
   the next junction and the next water point. A 20 m hysteresis keeps it from
   flickering between tracks that run close together.
5. Water is a POI beside the track rather than on it, so a water POI within 60 m
   of the line is attached to it; the distance is measured to the point where
   the track passes closest to it. Creeks, waterfalls and swimming holes count;
   the grouping lives in `app/lib/src/map/poi_groups.dart` so the map toggles and
   the metric cannot drift apart. The card says "Nearest water" when the walker
   is standing still, and "Water behind" once they have passed the last mapped
   water on that track.
6. `WalkTracker` adds up the distance between successive fixes, so the card can
   show how far the walker has covered. Hops under 4 m are ignored as GPS
   jitter while standing still, and stopping tracking resets the total rather
   than carrying a bus trip into the next walk. It counts movement off the
   mapped network too, and never goes down.
7. "Next" and "behind" need a bearing, and the fix's speed has to be at least
   0.7 m/s before a bearing is trusted. Where the platform reports neither — the
   web build among them — the card says "Nearest water" and "Nearest: Junction
   N" instead of guessing a direction.
8. The card above the bundle chip shows the track, the next junction, the
   distance, the estimated walk time at the bundle's pace and the fix accuracy,
   plus the distance walked and the next water point. Tapping it opens the
   junction's sheet. Fixes more than 150 m from every track are reported as "off
   the mapped tracks" with no junction answer.

Walk times reuse the bundle's flat-terrain pace (see
`segments.json`'s `estimate`); they are estimates and are labelled with `~`.

## Tests

- `app/test/trail_locator_test.dart` covers the geometry, including a walk
  along the real `paluma-track-circuit-5`, a check that every junction in the
  content sits on the network, and the water points attached to the real tracks.
- `app/test/walk_tracker_test.dart` covers the walked-distance accumulator,
  including jitter while standing still and resetting between walks.
- `app/test/location_service_test.dart` drives every permission and stream state
  through a fake location driver.
- `app/test/location_overlay_test.dart` covers what the card says in each state.

## Device checks

- Real device: tap the locate button, grant permission, confirm the puck and
  accuracy circle appear and that "off the mapped tracks" is shown away from
  Paluma.
- Emulator: `adb emu geo fix <lon> <lat>` walks the emulator through a track;
  the card should count down to the next junction, add to the walked distance
  and offer the next water point.

For repeatable on-track checks, device coverage and a results template, use
[the field-test plan](field-testing.md) (#51).
