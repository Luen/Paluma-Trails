# Web build and Docker image

The Flutter web build is a static site. `app/Dockerfile` builds it in a Flutter
image and serves it with Caddy.

## Run locally

From the repository root:

```sh
docker compose up --build
```

Then open <http://localhost:8080>. The first build pulls the Flutter image and
takes a few minutes; `docker compose down` stops it.

Caddy adds an SPA fallback and sets:

- `no-cache` for `/`, `index.html`, `flutter_service_worker.js`,
  `manifest.json` and `version.json`, so a new image is picked up instead of a
  stale service worker;
- a one-hour cache for `assets/` and `canvaskit/`.

## Published image

On a `v*` tag the Release workflow builds `app/Dockerfile`, starts the image,
checks the landing page and the service-worker cache header, then pushes:

- `ghcr.io/luen/paluma-trails-web:<version>` for every release;
- `ghcr.io/luen/paluma-trails-web:latest` for stable versions (no hyphen in the
  version).

Manual Release runs build and smoke-test the image but do not push it. The GHCR
package is private by default; make it public in the package settings if the
host should pull it anonymously.

## Hosting

The image is pull-based and ready for the hosting decision in #69: Watchtower,
an SSH pull step, a webhook, or static hosting from the web tarball. The server
choice is still open.
