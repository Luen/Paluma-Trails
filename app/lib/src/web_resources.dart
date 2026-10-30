/// Resolves a packaged web resource from the site's root, including when the
/// launch URL is a nested `/poi/<id>` route.
///
/// The current web deployment and POI contract serve the application at the
/// origin root. Resolving a relative asset against the launch URL instead
/// would request `/poi/assets/...` and receive the SPA HTML fallback.
Uri siteResourceUri(String path, {Uri? launchUri}) =>
    (launchUri ?? Uri.base).resolve('/$path');
