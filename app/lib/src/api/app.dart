import 'package:flutter/material.dart';

import '../content/bundle_repository.dart';
import '../map/map_options.dart';
import '../map/map_screen.dart';
import '../pmtiles_protocol.dart';

/// Root of the Paluma Trails app.
class PalumaTrailsApp extends StatefulWidget {
  const PalumaTrailsApp({super.key, required this.repository});

  final BundleRepository repository;

  @override
  State<PalumaTrailsApp> createState() => _PalumaTrailsAppState();
}

class _PalumaTrailsAppState extends State<PalumaTrailsApp> {
  final _options = MapOptions();

  @override
  void dispose() {
    _options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapOptionsScope(
      options: _options,
      child: ListenableBuilder(
        listenable: _options,
        builder: (context, _) => MaterialApp(
          title: 'Paluma Trails',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light, sunlight: _options.sunlight),
          darkTheme: _theme(Brightness.dark),
          // Sunlight mode is for a bright day, so it overrides a dark system
          // theme rather than following it.
          themeMode: _options.sunlight ? ThemeMode.light : ThemeMode.system,
          home: _BundleLoader(repository: widget.repository),
        ),
      ),
    );
  }

  static ThemeData _theme(Brightness brightness, {bool sunlight = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E6B4F),
      brightness: brightness,
      contrastLevel: sunlight ? 1.0 : 0.0,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: sunlight ? const Color(0xFFFFFFFF) : null,
    );
  }
}

/// Loads the offline bundle, then shows the map. The web PMTiles protocol has
/// to be registered before the map resolves its style, which is why it happens
/// here rather than in `main`.
class _BundleLoader extends StatefulWidget {
  const _BundleLoader({required this.repository});

  final BundleRepository repository;

  @override
  State<_BundleLoader> createState() => _BundleLoaderState();
}

class _BundleLoaderState extends State<_BundleLoader> {
  late final Future<LoadedBundle> _bundle = _load();

  Future<LoadedBundle> _load() async {
    final bundle = await widget.repository.load();
    registerPmTilesProtocol(bundle.pmtilesUri);
    return bundle;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoadedBundle>(
      future: _bundle,
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        if (bundle != null) return MapScreen(bundle: bundle);
        if (snapshot.hasError) return _BundleError(error: snapshot.error!);
        return const _LoadingScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening the offline map…'),
          ],
        ),
      ),
    );
  }
}

class _BundleError extends StatelessWidget {
  const _BundleError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 40,
              ),
              const SizedBox(height: 16),
              const Text(
                'The offline bundle could not be loaded.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
