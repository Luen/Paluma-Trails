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

### Build notes

The build stage installs Flutter 3.47.7 from the official release archive
instead of using a registry image: the available Flutter images still carry
Dart 3.12, while the app needs Dart 3.13.5. Keep `FLUTTER_VERSION` in
`app/Dockerfile` in sync when the project's Flutter version changes.

Flutter's Linux SDK is amd64-only, so the Dockerfile pins the build stage to
`linux/amd64`. The Caddy runtime is published for both `linux/amd64` and
`linux/arm64` so an Odroid or Raspberry Pi can pull a native image.

Caddy adds an SPA fallback and sets:

- `no-cache` for `/`, `index.html`, `flutter_service_worker.js`,
  `manifest.json` and `version.json`, so a new image is picked up instead of a
  stale service worker;
- a one-hour cache for `assets/` and `canvaskit/`.

## Published image

On a `v*` tag the Release workflow smoke-tests an amd64 image, then pushes a
multi-arch (`linux/amd64`, `linux/arm64`) manifest:

- `ghcr.io/luen/paluma-trails-web:<version>` for every release;
- `ghcr.io/luen/paluma-trails-web:latest` for stable versions (no hyphen in the
  version).

A manual Release run builds and smoke-tests the image. Tick **Push the
multi-arch web image to GHCR** to publish without cutting a git tag (useful to
republish the same version for arm64). The GHCR package is private by default;
make it public in the package settings if the host should pull it anonymously.

## Home server (pull only)

On a host that already has Docker (for example the Odroid), use the root
`docker-compose.yml`. No `.env` is required for the static site:

```sh
mkdir -p ~/paluma-trails && cd ~/paluma-trails
# place or clone docker-compose.yml here, then:
docker compose pull
docker compose up -d
curl -fsS http://127.0.0.1:8098/ | head
```

Prerelease tags (with a hyphen) are not also tagged `:latest`, so pin
`PALUMA_WEB_TAG` (or the default in `docker-compose.yml`) until a stable
release. If Docker warns that `linux/amd64` does not match the host, the
published tag is still single-arch — republish with the multi-arch workflow
above, then `docker compose pull` again.

## Hosting

The image is pull-based and ready for the hosting decision in #69: Watchtower,
an SSH pull step, a webhook, or static hosting from the web tarball. The server
choice is still open.
