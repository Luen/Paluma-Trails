/// Registers the `pmtiles://` protocol with MapLibre where the platform needs
/// the app to do that.
///
/// Android and iOS resolve `pmtiles://` URLs inside MapLibre Native, so the
/// stub implementation is a no-op there. On web the protocol is provided by the
/// `pmtiles` JavaScript library loaded from `web/index.html` and registered by
/// [registerPmTilesProtocol].
library;

export 'pmtiles_protocol_stub.dart'
    if (dart.library.js_interop) 'pmtiles_protocol_web.dart';
