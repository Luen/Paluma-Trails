# Roadmap

Status legend: **shipped** (in `dev`), **next** (in progress), **later**, **open**
(decision needed first).

The GitHub issues are the source of truth for detail; this page is the bird's-eye
view. Epic issues are linked.

## Milestone 0 — Foundation (this branch)

| Work | Issues |
| --- | --- |
| Platform decisions recorded | #3, #4, #5, #16 (ADRs 0001–0006) |
| Monorepo layout, CI on PRs, contribution docs, templates | #6, #64 |
| Content schema + real Paluma data + validation in CI | #9, #10 |
| Junction graph: distances and estimated times between junctions | #11 |
| Offline bundle builder with manifest (version, size, hashes) | #12 |
| Walking skeleton: app renders the offline map, tracks, junctions, POIs | #15, #18, #19, #26 (partial) |

## Milestone 1 — Planning website (Flutter web)

- Web map page and printable map (#22)
- Auto-download / update of the park bundle with Wi-Fi-or-data preference (#17)
- Outdoor-friendly map UI pass, high contrast, battery saver (#21)
- Live trail metrics while tracking: distance walked and the next water (#55)
- Weather card with cached offline copy (#39) — depends on #38

## Milestone 2 — Points of interest and QR codes

- Shortlist and research POIs; content with citations (#24)
- Offline POI detail pages with historic photos and credits (#26, #28)
- Toggleable marker groups so the map stays readable (#56)
- QR URL scheme so codes never change (#25)
- Sign design, permissions, installation (#27, #44)

## Milestone 3 — Offline-first track issue reporting

- Report form with GPS, photo, minimal typing (#32)
- Offline queue with visible pending/sent status (#33)
- Intake backend and triage dashboard (#34) — depends on #31, #36
- Public hazard layer and last-maintained dates (#35)

## Milestone 4 — Weather, conditions and safety

- Safety guidance and the offline emergency screen (#41, #42) — **shipped**;
  reception points (#60) still need field verification
- Investigate BOM access and licensing (#38)
- Park alerts and closures (#40)
- Emergency screen: coordinates and known reception points (#42, #60)

## Milestone 5 — Launch, quality and operations

- MVP scope agreed (#50), field-test plan (#51), accessibility review (#53)
- App store publishing setup (#52), secrets and signing (#66)
- Release workflow: tags, GitHub Release, store uploads (#65, #67)
- Content update and release process (#54)
- Docker image for the web build (#68) and deployment method (#69)

## Backlog ideas

Route planner (#20), elevation profiles (#14), user waypoints (#57), trail notes
for both directions (#58), walk simulation (#59), trip-planning hub (#61), scan
analytics (#29), funding (#48), cross-linking with wanderstories.space (#47).
