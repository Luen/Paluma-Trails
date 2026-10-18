import 'models.dart';

/// Web: the bundle stays where the browser serves it, so there is nothing to
/// materialise.
Future<String?> materialiseBundle(BundleManifest manifest) async => null;
