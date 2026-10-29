# QR codes and links

A sign on a track carries a QR code. Scanning it opens the same point of
interest in the app, or on the website when the app is not installed. The code
is printed once and must keep working for years, so the scheme is deliberately
boring and the app ignores everything that is allowed to change.

## The scheme

| Form | Use |
| --- | --- |
| `https://<host>/poi/<id>` | The canonical link a QR code encodes |
| `https://<host>/?poi=<id>` | Fallback for hosts that cannot rewrite paths |
| `paluma://poi/<id>` | Accepted now so native app links need no new codes later |

`<id>` is the POI's content id from `content/data/paluma/pois.json`, for
example `gold-creek-falls`. Ids are permanent (see `docs/content-model.md`):
adding or renaming content never reuses an old id, because a reused id would
quietly change what an existing sign points at.

The host is **not** part of the contract. The app reads only the path and the
id, so the site can move from one domain to another and old codes still work.
The host still has to be chosen before the first sign is printed — that is part
of #25/#27, not of this parser.

## What the app does

1. At launch it reads the launch URL (`Uri.base`) and parses a POI id.
2. Once the offline map is ready it centres on the POI and opens its sheet.
3. An id the bundle does not have is reported: “That point of interest is not
   in this version of the map.” The map still opens, so a stale sign is never a
   dead end.

Everything after the launch is offline. The link itself needs a connection only
because the browser has to load the website the first time; a walker with the
app installed does not need one.

## Host requirements

The path form needs the web host to answer unknown paths with `index.html`.
The Caddy image in `app/Dockerfile` already does this. A plain static server
(for example `python -m http.server`) returns 404 for `/poi/<id>`, so use the
`?poi=<id>` form there.

## Not in this slice

- **Choosing the printed host and generating the QR images.** Both wait on the
  site's final address (#25, #27).
- **Native app links.** Android needs an `assetlinks.json` and an intent
  filter; iOS needs an associated-domain entitlement. `paluma://poi/<id>` is
  already parsed so those can be added without touching the codes.
- **Scan analytics.** Deliberately not designed yet; see #29 for the privacy
  question.

## Code

- `app/lib/src/deep_links.dart` — parsing and the id pattern.
- `app/test/deep_links_test.dart` — the accepted and rejected forms.
- `app/lib/src/map/map_screen.dart` — opening the POI once the map is ready.
