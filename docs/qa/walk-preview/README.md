# Walk-preview QA

- [Light/dark controls](light-dark.png)
- [Sunlight/large-text controls](sunlight-large.png)
- [Actual map playback](map-playback.png)

These show the actual Flutter controls with an explicitly named simulated
example. They are component previews, not field observations or real GPS.
The 320 px, 2× text regression test also exercises pause/resume/restart and
checks for layout errors. A first test caught a wide speed selector; the final
selector uses a short value with a separate label.

Browser accessibility inspection confirmed separate labelled Pause, Restart
and Speed buttons and a separate progress node. The first implementation let
the progress indicator absorb the controls into its semantics node; the final
version gives it a separate container.

The real web flow was exercised from About, selecting Bullocky Tom's Track,
starting a preview and observing simulated distance/progress. The preview's
title and GPS-off label remain explicit. Waypoint and emergency actions are
excluded. No live location permission was requested or granted during review.

The initial simple HTTP test server lacked byte-range support and could not
serve PMTiles correctly; PMTiles QA must use a range-capable server such as the
production Caddy setup. The final browser test used byte-range serving and
rendered the basemap correctly. Restart reset simulated walked distance to
zero. After exiting, the real emergency screen reported location off and had
no simulated coordinates. This hosting limitation is separate from simulation.

The model/service regression tests and browser preview do not establish real
device GPS suspend/resume or native background behaviour. Those remain field
checks. See [the feature notes](../../walk-preview.md).
