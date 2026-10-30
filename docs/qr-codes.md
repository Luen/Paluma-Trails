# QR codes and links

A sign on a track carries a QR code. Scanning it opens the same point of
interest in the app, or on the website when the app is not installed. The code
is printed once and must keep working for years, so the address follows
[ADR 0009](decisions/0009-poi-urls.md) and the app reads only what the ADR makes
permanent.

## The address

```
https://<origin>/poi/<poi-id>
```

That is the only printed form. `<poi-id>` is the POI's content id from
`content/data/paluma/pois.json` — `buttercup-lookout`, `gold-creek-falls`. Ids
are permanent (see [content-model.md](content-model.md)); a display-name
correction never changes an id, because a reused id would quietly change what an
existing sign points at.

There is no second sequence in `qr_id`, no query string identity, no shortener
and no custom app-only scheme in the code. The origin is a **deployment input**:
the app ignores it, so moving the site leaves printed codes working, but the
origin still has to be chosen and kept for the life of the signs.

## What the app does

1. At launch it reads the launch URL (`Uri.base`) and parses a POI id.
2. Once the offline map is ready it centres on the POI and opens its sheet.
3. An id the bundle does not have opens a not-found sheet that names the id,
   explains that the entry may have been added after this copy was downloaded or
   renamed since the sign was printed, and offers one 48 dp action back to the
   map. A stale sign is never a blank page.

Parsing is strict, per ADR 0009: exactly one `poi` segment and one id, decoded
once. Extra segments, encoded separators, traversal and ids outside the content
grammar are rejected, and the map opens instead. Case is normalised because ids
are stored lowercase and a hand-typed link cannot collide with another POI.

Everything after the launch is offline. The link itself needs a connection only
because the browser has to load the website the first time; a walker with the
app installed and the bundle downloaded does not need one.

## What hosting must do

The origin must serve `/poi/<id>` itself, not redirect it to `/?poi=<id>` and
not drop the id on an SPA fallback. The Caddy image in `app/Dockerfile` serves
`index.html` for unknown paths, so the Flutter app receives the original URL;
a host that only redirects to `/` needs fixing before a sign is printed.

The offline caveat is real: a first scan without reception cannot download the
website, and the ADR requires signs to tell walkers to prepare the app or map
before losing signal. Nothing in the app should promise otherwise.

## Still open

- **Choosing the origin, alias policy and redirects.** A deployment decision,
  recorded with #27 before any sign is printed.
- **Verified Android App Links / iOS Universal Links.** These need the final
  origin, association files and signing identities; declaring a handler is not
  verification.
- **Aliases for renamed or retired ids.** The not-found sheet explains the
  situation today; section 0009 requires explicit, versioned aliases so an old
  sign can resolve offline.
- **QR images and the physical sign**, including land-manager permission (#27,
  #44).
- **Scan analytics**, deliberately not designed; see #29 for the privacy
  decision.

## Code

- `app/lib/src/deep_links.dart` — parsing and the id grammar.
- `app/test/deep_links_test.dart` — accepted and rejected forms.
- `app/lib/src/map/poi_link_sheet.dart` — the not-found sheet.
- `app/lib/src/map/map_screen.dart` — opening the POI once the map is ready.
