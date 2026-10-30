import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'src/api/app.dart';
import 'src/brand/brand.dart';
import 'src/content/bundle_repository.dart';
import 'src/deep_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Injecting the MapLibre GL JS bundle happens asynchronously; the PMTiles
    // protocol registration (see _BundleLoader) needs the JS globals.
    await MapLibreMap.ensureWebLibraryLoaded();
  }
  registerBrandLicences();
  runApp(
    PalumaTrailsApp(
      repository: BundleRepository(),
      initialLink: parseDeepLink(Uri.base),
    ),
  );
  // The web splash is an HTML overlay, so it needs an explicit removal after
  // the first frame. On Android and iOS the launch screen is already gone.
  FlutterNativeSplash.remove();
}
