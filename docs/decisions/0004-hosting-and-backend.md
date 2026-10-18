# ADR 0004: Hosting and backend

- **Status:** Accepted for content hosting; Proposed for report intake
- **Date:** 2026-10-16
- **Issues:** #5, #12, #34, #69

## Context

Issue #5 asks where content bundles and the website are hosted, and what receives
track-issue reports. Constraints: cost near zero, privacy for reporters' data
(location + photos), and low operational burden for volunteers.

## Decision

**Content (accepted).** Content lives in git under `content/`. Release bundles
are built in CI and published as **GitHub Release assets** on this repository
(versioned, immutable, free CDN). The app points at the release URL in its content
manifest and can check for updates without a backend of our own.

**Website (accepted).** `flutter build web` output is published as a container
image (`ghcr.io/luen/paluma-trails-web`) and/or static hosting. The final host is
a deployment detail; see #68 and #69.

**Report intake (proposed — confirm before implementing #34).**
**Cloudflare Workers + D1 (report records) + R2 (photos)**, because:

- Free tier covers the expected volume by a wide margin, and it can scale to zero.
- A Worker can do spam protection (Turnstile / rate limits) and strip EXIF (#36)
  before storing photos.
- Data can be exported as JSON/CSV for the receiving volunteer team.
- It does not require operating a server.

Alternative kept in reserve: **GitHub Issues** as the intake (zero infra, familiar
triage) with photos stored in R2 — rejected as the primary because a public tracker
is a poor place for reporters' location data and it complicates the API.

## Rationale

- Keeping content in git and bundles on GitHub Releases means the project has no
  backend to run for the MVP path (map + POIs), which is the riskiest part to get
  wrong.
- Reports are the only feature that truly needs a service; deferring the choice
  until epic #30 is implemented does not block anything else, but recording the
  intent now keeps the app's sync client interface honest (an HTTP POST of a
  report + optional multipart photo).

## Consequences

- GitHub Releases must stay under licence-compatible use; bundles contain our own
  content plus attribution for third-party data.
- If Cloudflare is not acceptable later, the intake contract is one endpoint
  (`POST /reports`) and one storage bucket, so swapping providers is contained.
- Privacy policy work (#36) must land before intake goes live.
