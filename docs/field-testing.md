# Field-test plan

This plan covers #51: offline use, GPS under canopy, outdoor readability and
battery use on the actual Paluma tracks. It is a repeatable test protocol, not a
record of a completed walk or proof that a track is open. Save one copy of the
[report template](field-test-report.md) for each device/build/session.

## Before going out

A maintainer and the testers agree on a short, familiar route, a turnaround time,
a check-in person and a fallback navigation method independent of this app.
Check current official access/closure information before choosing the route.
Use accessible, permitted tracks; stop the test if conditions or navigation are
uncertain. Never make a real emergency call to test the app.

Pick a route with numbered junctions, a mapped POI and water point, and both
open sky and canopy if safely available. Write the actual track/junction IDs
and expected order in the report from `content/data/paluma/`; do not assume a
straight line between junctions is a walking route. Include a place where two
tracks are close together if the chosen route safely allows it. Do not walk off
track to provoke an error; test off-network behaviour at a safe access point
or with recorded/simulated locations before the trip.

Record these **before** the test:

- App release, git revision, bundle version from the map, and `park.updated`.
- Phone, OS, battery health if available, screen brightness, theme/text size,
  power mode, other active apps and start battery/time. Note screen-on time.
- Planned route, direction, distance, checkpoints and reference method. A sign
  identifies a junction but is not a surveyed coordinate reference; a second
  phone or the basemap alone cannot establish absolute GPS accuracy.
- Network state, location permission/precise-location setting, and whether the
  build has already been launched online. Bring the report and plan offline.

## Device coverage

Use physical devices for GPS and battery results. Emulator fixes are useful
before the walk but cannot demonstrate canopy accuracy or power use.

| Target | Required checks |
| --- | --- |
| Android phone | Fresh install/first launch offline, restart offline, tracking, map, POIs, daylight, battery comparison |
| iPhone | Same native checks when a signed build is available; explicitly mark blocked until then |
| Mobile browser/PWA | Load online first, then offline reload/reopen, cached map coverage, browser location permission and foreground behaviour |
| Desktop browser | Planning/POI smoke test before the trip; no substitute for field GPS/battery results |

Report an untested device as **not tested**. Native bundled assets should work
on the first launch offline. Browser first visits require connectivity; record
cache failures as failures and do not assume a PWA works offline just because
the page stayed open. Separate those results from native first-launch results.

## Test cases

Use **pass / fail / blocked / not tested**, with evidence, for every row.

| ID | Action | Expected result / evidence |
| --- | --- | --- |
| O1 | Install a native build, disable Wi-Fi and mobile data before first launch, leave location enabled, open the app | Map, basemap labels, tracks, junctions and POIs load without downloads; record bundle version |
| O2 | Pan and zoom along the whole chosen route offline; open junction and POI sheets, route planner, About and Safety | No missing essential tiles/text, crash or network-dependent spinner; estimates retain their labels; attribution remains available |
| O3 | Stop/close and reopen the app while still offline | Bundle remains usable; personal waypoints from a previous session remain available; record any startup delay/error |
| O4 | For web, load online, disable network, reload and reopen; pan to route areas not previously viewed | Record exactly which assets/areas work; missing cached content is a failure for that scenario, not an assumed pass |
| G1 | Tap locate with permission denied, then grant it; separately disable/re-enable device location | Clear explanation and recoverable action; granting permission and tapping locate again recovers tracking |
| G2 | Start tracking at an open-sky checkpoint and then under canopy | Record time to first fix, reported accuracy, reference position/method and observed offset separately; no false precision claims |
| G3 | Walk between known signs in each direction, including a stationary pause | Record sign IDs, GPS coordinates, accuracy and time. Correct track/junction is shown, distances trend sensibly, no persistent jumps between nearby tracks |
| G4 | Stop at a checkpoint, then resume; pass a mapped water point if on route | Record GPS jitter and distance accumulated while stopped; nearest/next/behind wording agrees with the available direction information |
| G5 | Pan away while following, then tap locate; stop/restart tracking | Follow can be regained, distance does not include a previous walk, and map controls remain usable |
| S1 | Open Safety while tracking and again with no fix | Coordinates/accuracy or an explicit unavailable state; no stale fix represented as current; no test calls placed |
| R1 | Read the map, junction card and Safety in open daylight and shade | Record glare/brightness; essential text and controls are legible in light, dark and sunlight modes |
| R2 | Use large system text and a screen reader; open long sheets and all primary actions | No clipped essential text, inaccessible controls or actions requiring a hidden gesture; record any overflow and affected device settings |
| B1 | Run the battery protocol below | Comparable measurements for normal and saver mode, with tracking continuity and screen state recorded |

The locator intentionally ignores tiny hops, uses hysteresis between nearby
tracks, and only infers travel direction with sufficient speed/bearing. Compare
observations with [the location contract](location.md) rather than requiring a
specific junction direction while stationary. Mark inconsistent/stale location,
missing content or an incorrect route as a defect even if no crash occurs.

## Battery protocol

1. Use the same phone/build/route, brightness, network state and duration for
   normal and battery-saver runs. Aim for at least 60 minutes per run; record
   the actual duration. Avoid charging and other deliberate heavy use.
2. Record battery percentage, clock time and screen state at start, every
   checkpoint and finish. Record temperature/thermal warnings and any calls or
   interruptions. Repeat the walk/session for the other mode; alternate order
   on a repeat day if practical to reduce order effects.
3. Include a stationary screen-locked interval in each session. On unlock,
   record whether tracking paused, caught up or lost the stream. The current
   app does not promise continuous OS background location; report foreground
   and locked-screen observations separately.
4. Compute `percentage points used × 60 / elapsed minutes` for each run. Record
   distance and fix behaviour as well: lower drain with unusable fixes is not a
   successful saver result. Percent readings are coarse, especially for short
   runs; repeat surprising results before attributing them to a mode.

There is no agreed launch power or canopy-accuracy budget yet. Before calling
those measurements acceptable, the maintainer must record the agreed target,
route, device and measurement method in the report. Until then, publish raw
measurements and mark launch acceptance **pending**, rather than inventing an
accuracy guarantee or treating any drain as a pass.

## Reporting and release gate

Attach the completed report to a GitHub issue/PR, with screenshot timestamps and
reproduction steps. Share only observations needed for the defect; keep personal
journeys, private waypoints and identifiable bystanders out of public attachments.
Reception observations must include date, carrier, device, exact location and
what was observed. A signal icon is not proof that a call works. Field notes do
not automatically become verified reception points or official safety guidance;
that review remains #60.

Any crash, missing offline map/safety content, misleading location, unusable
primary control or unexplained loss of saved waypoints blocks acceptance for
that tested build. File a separate defect with the test ID and build/bundle
versions, correct it, then rerun the failed case and affected offline/location
flows. Blocked platform coverage and pending battery/accuracy targets stay
visible for the release maintainer to decide before launch. Store accounts,
closure verification and physical fieldwork cannot be replaced by CI.
