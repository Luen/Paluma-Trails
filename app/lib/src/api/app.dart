import 'package:flutter/material.dart';

import '../content/bundle_repository.dart';
import '../map/map_screen.dart';
import '../pmtiles_protocol.dart';

/// Root of the Paluma Trails app.
class PalumaTrailsApp extends StatelessWidget {
  const PalumaTrailsApp({super.key, required this.repository});

  final BundleRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paluma Trails',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: _BundleLoader(repository: repository),
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E6B4F),
      brightness: brightness,
    );
    return ThemeData(colorScheme: scheme, useMaterial3: true);
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
