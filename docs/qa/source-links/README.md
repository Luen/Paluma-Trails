# Online source links

Actual Flutter component previews in light/dark and sunlight/2× text. The
external-link icon and “Read online” label distinguish the network action from
the already bundled citation. Minimum tap height is 48 dp. The label wraps at
320 px with 2× text in widget tests. No network request is made before a tap;
failed launches leave the offline citation visible with a short explanation.

See `app/lib/previews.dart` and `app/test/source_link_test.dart`.
