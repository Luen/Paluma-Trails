import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'src/api/app.dart';
import 'src/content/bundle_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Injecting the MapLibre GL JS bundle happens asynchronously; the PMTiles
    // protocol registration (see _BundleLoader) needs the JS globals.
    await MapLibreMap.ensureWebLibraryLoaded();
  }
  runApp(PalumaTrailsApp(repository: BundleRepository()));
}
