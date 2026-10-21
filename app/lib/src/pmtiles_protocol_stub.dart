/// Stub for Android and iOS, where MapLibre Native resolves `pmtiles://`
/// URLs itself and no registration is needed.
///
/// The web implementation lives in `pmtiles_protocol_web.dart`.
void registerPmTilesProtocol(String archiveUrl) {
  // No-op on native platforms.
}
