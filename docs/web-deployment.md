# Web build and Docker image

The Flutter web build is a static site. `app/Dockerfile` builds it in a Flutter
build stage and serves it with Caddy.

## Run locally

From the repository root:

```sh
docker compose up --build
```

Then open <http://localhost:8098>. Override the host port or image tag if
needed:

```sh
PALUMA_WEB_PORT=8080 docker compose up --build
PALUMA_WEB_TAG=latest docker compose pull && docker compose up -d
```

The first build downloads the Flutter SDK (about 1.6 GB) and takes a few
minutes, so allow several GB of free disk; `docker compose down` stops it.

## Home server (pull only)

On a host that already has Docker (for example the Odroid), copy
`docker-compose.yml`, pull the published image, and start it. No `.env` is
required for the static site:

```sh
mkdir -p ~/paluma-trails && cd ~/paluma-trails
# place docker-compose.yml here, then:
docker compose pull
docker compose up -d
curl -fsS http://127.0.0.1:8098/ | head
```

Prerelease tags (with a hyphen) are not also tagged `:latest`, so pin
`PALUMA_WEB_TAG` (or the default in `docker-compose.yml`) until a stable
release. The GHCR package may be private; log in with a token that has
`read:packages` if anonymous pulls fail.

### Build notes

The build stage installs Flutter 3.47.7 from the official release archive
instead of using a registry image: the available Flutter images still carry
Dart 3.12, while the app needs Dart 3.13.5. Keep `FLUTTER_VERSION` in
`app/Dockerfile` in sync when the project's Flutter version changes.

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
