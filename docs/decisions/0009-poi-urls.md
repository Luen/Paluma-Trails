# ADR 0009: Permanent POI URLs for QR signs

- **Status:** Proposed
- **Date:** 2026-10-29
- **Issues:** #25, #27, #22

## Context

Printed signs outlive app versions, hosting providers and display names. ADR
0002 reserves `/poi/<id>` for the shared web/app experience. The current app
shows bundled POIs from the map; URL dispatch, verified app links and static
fallbacks are not implemented. No production QR origin has been selected.

## Decision

Use `https://<maintainer-controlled-origin>/poi/<poi-id>` as the canonical
public address. The origin is a deployment input, not a placeholder to print.
Use the existing stable `id` from `content/data/paluma/pois.json`: for example
`/poi/gardes-lookout` and `/poi/shays-clearing`. Display-name/spelling corrections
must not regenerate IDs. The visible fallback code is the same POI ID; do not
create a second sequence in the currently optional `qr_id` field.

Choose one HTTPS origin the maintainer can retain and redirect for the lifetime
of installed signs. Do not use a release tag, bundle version, URL shortener,
query-based tracking ID or custom app-only URI in the printed code. Origin
selection and an alias/redirect policy must be confirmed before printing (#27).

## Required behaviour before signage

- Installed app: verified Android App Links/iOS Universal Links open the POI
  from packaged content without requiring a network fetch. This requires the
  chosen host's association files and the final signing identities; merely
  declaring a URL handler is not verification. Follow the official
  [Android verification guide](https://developer.android.com/training/app-links/verify-applinks)
  and [Apple Universal Links guide](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app).
- Browser: a fresh online visit to the same path renders the correct POI, with
  a static text/photo-credit fallback if Flutter is unavailable. Hosting must
  serve that path correctly, rather than dropping the ID on an SPA redirect.
- Offline browser: previously cached content may be available only after a
  tested cache/install flow. A first scan without reception cannot download a
  website. Signs must tell walkers to prepare the app/map before losing signal;
  never promise every camera scan can launch an offline website.
- Unknown IDs show an understandable not-found screen with map/search access.
  Renamed/retired entries retain an alias or explanatory landing page; IDs are
  never reassigned to a different site. Aliases must be explicit, cycle-free and
  kept in versioned content when offline resolution is required.
- Decode a single path segment once; reject encoded separators, traversal,
  extra path segments and IDs outside the content ID grammar. External/untrusted
  origins must not be treated as verified project links. Query parameters do
  not alter POI identity; do not add scan analytics without the separate #29
  privacy decision.

## Consequences and verification

This establishes an address contract, not permission to place signs. Domain,
association files, routing/fallback implementation, cache coverage and physical
installation remain outstanding. Keep #25 open until its app/web behaviour is
verified; #27 also depends on land-manager permission (#44).

Before printing, test a real QR on fresh online Android/iOS/browser installs,
an installed app in flight mode, a prepared offline browser, denied camera/app
link handling, unknown/retired IDs, hostile encodings and a renamed POI. Record
the exact URLs and tested release. The readable POI ID must still let a walker
find the entry on the offline map if the QR is damaged.
