# Location and the next junction

The map can show where the walker is (blue dot, heading, accuracy circle) and
how far the next junction is **along the track**. Everything works with the
network off: the fixes come from the device's own location provider and the
distances from the offline bundle.

## Flow

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
   the next junction. A 20 m hysteresis keeps it from flickering between tracks
   that run close together.
5. The card above the bundle chip shows the track, the next junction, the
   distance, the estimated walk time at the bundle's pace and the fix accuracy.
   Tapping it opens the junction's sheet. Fixes more than 150 m from every
   track are reported as "off the mapped tracks" with no junction answer.

Walk times reuse the bundle's flat-terrain pace (see
`segments.json`'s `estimate`); they are estimates and are labelled with `~`.

## Tests

- `app/test/trail_locator_test.dart` covers the geometry, including a walk
  along the real `paluma-track-circuit-5` and a check that every junction in
  the content sits on the network.
- `app/test/location_service_test.dart` drives every permission and stream state
  through a fake location driver.
- `app/test/location_overlay_test.dart` covers what the card says in each state.

## Device checks

- Real device: tap the locate button, grant permission, confirm the puck and
  accuracy circle appear and that "off the mapped tracks" is shown away from
  Paluma.
- Emulator: `adb emu geo fix <lon> <lat>` walks the emulator through a track;
  the card should count down to the next junction.
