# syntax=docker/dockerfile:1

# Build the Flutter web bundle. The release workflow builds this image and
# pushes it to GHCR; `docker compose up --build` builds it locally.
#
# Flutter's official Linux SDK is amd64-only, so the build stage is always
# linux/amd64. The runtime stage is plain Caddy and is published for both
# amd64 and arm64 (Odroid / Raspberry Pi home servers).
#
# Registry Flutter images lag the stable channel (the newest cirruslabs tag is
# Flutter 3.44.0 / Dart 3.12, while the app needs Dart 3.13.5), so install the
# same SDK version used by CI directly. Bump FLUTTER_VERSION with the stable
# channel.
FROM --platform=linux/amd64 debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.7
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      unzip \
      xz-utils \
      zip \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && git config --global --add safe.directory "${FLUTTER_HOME}" \
 && flutter config --no-analytics \
 && flutter precache --web

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM caddy:2-alpine
COPY --from=build /app/build/web /srv
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80
