import 'package:flutter/material.dart';

import '../brand/brand.dart';
import '../brand/theme.dart';
import '../content/bundle_repository.dart';
import '../deep_links.dart';
import '../map/map_options.dart';
import '../map/map_screen.dart';
import '../pmtiles_protocol.dart';

/// Root of the Paluma Trails app.
class PalumaTrailsApp extends StatefulWidget {
  const PalumaTrailsApp({
    super.key,
    required this.repository,
    this.initialLink,
  });

  final BundleRepository repository;

  /// A POI from a QR code or shared link, opened on top of the map at launch.
  final DeepLink? initialLink;

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
          title: BrandText.name,
          debugShowCheckedModeBanner: false,
          theme: buildPalumaTheme(
            Brightness.light,
            sunlight: _options.sunlight,
          ),
          darkTheme: buildPalumaTheme(Brightness.dark),
          // Sunlight mode is for a bright day, so it overrides a dark system
          // theme rather than following it.
          themeMode: _options.sunlight ? ThemeMode.light : ThemeMode.system,
          home: _BundleLoader(
            repository: widget.repository,
            initialLink: widget.initialLink,
          ),
        ),
      ),
    );
  }
}

/// Loads the offline bundle, then shows the map. The web PMTiles protocol has
/// to be registered before the map resolves its style, which is why it happens
/// here rather than in `main`.
class _BundleLoader extends StatefulWidget {
  const _BundleLoader({required this.repository, this.initialLink});

  final BundleRepository repository;
  final DeepLink? initialLink;

  @override
  State<_BundleLoader> createState() => _BundleLoaderState();
}

class _BundleLoaderState extends State<_BundleLoader> {
  late Future<LoadedBundle> _bundle = _load();

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
        if (bundle != null) {
          return MapScreen(
            bundle: bundle,
            initialPoiId: widget.initialLink?.poiId,
          );
        }
        if (snapshot.hasError) {
          return _BundleError(
            error: snapshot.error!,
            onRetry: () => setState(() => _bundle = _load()),
          );
        }
        return const LoadingScreen();
      },
    );
  }
}

/// Shown while the offline bundle opens. It continues the launch screen (the
/// same rainforest field and cream mark) so start-up reads as one surface.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: BrandColors.rainforest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TrailPinMark(height: 96, accentColor: BrandColors.sand),
                const SizedBox(height: 24),
                const Wordmark(fontSize: 36, color: BrandColors.cream),
                const SizedBox(height: 8),
                Text(
                  BrandText.tagline,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: BrandColors.paleMist,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    color: BrandColors.sand,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Opening the offline map…',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: BrandColors.cream,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BundleError extends StatelessWidget {
  const _BundleError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  'The offline map could not open.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
