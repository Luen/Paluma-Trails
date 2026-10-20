# syntax=docker/dockerfile:1

# Build the Flutter web bundle. The release workflow builds this image and
# pushes it to GHCR; `docker compose up --build` builds it locally.
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM caddy:2-alpine
COPY --from=build /app/build/web /srv
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80
