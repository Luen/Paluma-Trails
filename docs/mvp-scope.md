# MVP scope and launch gates

Scope for #50: ship the planning website and an offline walking companion first.
Use the same Flutter app and packaged content on web and Android. QR signage,
report collection and store publication follow once their external dependencies
are resolved. This is a delivery plan, not a claim of park-manager endorsement or
field verification.

## First usable release

A walker can prepare a route before leaving reception, open the installed app in
flight mode, read the trail map and junction distances, see **estimated** walking
times, and read bundled POI text and photographs with credits. Location remains
optional: denying it must still leave the map, planning and content usable.

| Capability | Implementation in `dev` | Launch evidence still needed |
| --- | --- | --- |
| Offline map, tracks, junctions and POIs | Packaged assets; no first-run download required | Fresh install and flight-mode test on physical devices |
| Shortest route, out-and-back and loop planning | Route planner, totals and estimated times | Compare representative routes with field observations |
| GPS position, next junction and water, saved waypoints | Local device features | Real GPS, denied permission and stale-location tests |
| POI history and attributed photographs | Sourced content for a subset of POIs; remaining research is tracked in #24 | Check captions and readability outdoors; do not describe all sites as researched |
| Safety information | Offline safety screen | Complete the safety scenarios in the field-test protocol; reception points in #60 need verification |
| Planning website and Android downloads | Web build/container and per-ABI APK release pipeline | Select and verify the public web host (#69); install release APK on real devices |

The current web build needs an initial connection. An installed Android build
ships its content. Do not promise an independently downloaded bundle or automatic
updates until #17/#87 are implemented and tested.

## Milestones

1. **Reviewable builds.** Green app/content CI, versioned GitHub Release assets,
   matching app version, licence/permission inventory and a documented recovery
   process. This delivers testable software; it is not the public-launch gate.
2. **Field pilot.** Run [the field-test protocol](field-testing.md), fill in
   [the report](field-test-report.md), and fix blocking failures. Complete the
   screen-reader, large-text and contrast review in #53. Unknown physical track
   accessibility stays unknown. No unverified reception claim is added.
3. **Public map and walking companion.** Verify the chosen web deployment (#69),
   repeat fresh-install/offline checks on release artifacts, publish clear
   sideload instructions and record remaining limitations. Store distribution
   requires #52/#66 and the outstanding parts of #65; a debug-signed APK does
   not satisfy those gates.
4. **POI and QR rollout.** Finish the priority research (#24), choose permanent
   URLs/deep links (#25), and test app/web fallbacks before printing. Signage
   (#27) waits for land-manager permission (#44), placement and maintenance
   arrangements. Existing bundled POI pages can ship before physical signs.
5. **Reports and live conditions.** Agree report recipients and fields (#31),
   privacy/retention (#36), and the proposed intake architecture before #34.
   Then deliver the offline form/queue (#32/#33) and moderated hazard layer
   (#35). Weather (#38/#39) and park alerts (#40) need cached timestamps,
   source links and explicit unavailable/stale states.

## Release decision

The maintainer records the tested commit, device/browser matrix, field report,
blocking defects and remaining limitations in the release review. Public launch
requires passing the field-pilot and deployment gates above; merging a scope
document or publishing a GitHub Release alone does not establish readiness.

Elevation profiles (#14), simulation (#59), directional notes (#58), the trip
hub (#61), analytics (#29) and funding research (#48) may proceed independently,
but do not hold up the initial map/offline pilot. Network features must never
prevent access to already packaged trail information.

See [the roadmap](roadmap.md) for issue links and
[the release runbook](release.md) for the release procedure.
