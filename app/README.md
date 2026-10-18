# Paluma Trails — app

The Flutter client for the Paluma Trails offline guide. It renders the park
basemap and trail content from the bundle committed under
`assets/bundle/` (see `tools/basemap/README.md` and `docs/content-model.md`).

## Run

```sh
flutter pub get
flutter run              # Android / iOS
flutter run -d chrome    # web; if the basemap tiles fail to load, use the
                         # build + serve route below (range requests)
```

The map stack is MapLibre GL on top of a vector PMTiles archive
(ADR 0003). On Android and iOS the archive is copied to the app documents
directory on first launch and read with `pmtiles://file://…`. On the web it is
fetched from the site origin with HTTP range requests, so the host must support
`Range`. For a local check, build the web app and serve `build/web` with a
range-capable static server:

```sh
flutter build web --release
npx serve build/web
```

## Structure

```
lib/
  main.dart                  entry point; loads MapLibre GL JS on web
  src/
    api/app.dart             root widget; bundle loading, theme, error states
    about_screen.dart        park facts, attributions, disclaimers
    content/                 bundle loading and typed models
    map/map_screen.dart      the map, trail layers, tap handling
    map/sheets.dart          junction / POI / track bottom sheets
    map/format.dart          distance, duration, bearing formatting
    pmtiles_protocol*.dart   pmtiles:// registration (web) / no-op (native)
```

## Tests

```sh
flutter test
```

The bundle is regenerated with `tools/paluma_cli`; do not edit files under
`assets/bundle/` by hand:

```sh
cd ../tools/paluma_cli
dart run bin/paluma_cli.dart bundle build
```
