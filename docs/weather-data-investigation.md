# BOM forecast data investigation

Research for #38; checked 2026-10-29. No live weather feature or forecast data is
added to the app by this document. #39 remains the implementation issue.

## Findings and source choice

The owner confirmed BOM data permission in
[#37](https://github.com/Luen/Paluma-Trails/issues/37). Record the approved
product, attribution, redistribution and offline-cache terms with the selected
integration. Do not infer a Creative Commons licence or publish private
credentials in the repository.

BOM documents **`IDQ11295`, the Queensland Précis Forecast XML package**, in its
[Text Forecasts User Guide](https://www.bom.gov.au/catalogue/Bureau_of_Meteorology_text_forecasts_user_guide.pdf)
(version 2.1, 24 April 2026). It includes a short summary, temperatures, rain
probability/range and icon codes. It is a daily forecast, not a live observation,
hourly forecast or complete warnings service. Location data is described in the
[spatial data guide](https://www.bom.gov.au/catalogue/Bureau_of_Meteorology_spatial_data_user_guide.pdf).

The published anonymous-feed location is
`ftp://ftp.bom.gov.au/anon/gen/fwo/IDQ11295.xml`. Registered products also have
FTP/SFTP access. Use a server-side adapter for an authorised product and serve a
small HTTPS response to Flutter; browsers cannot consume the FTP feed directly,
and credentials must not be distributed with an app. This is an integration
recommendation, not a deployed endpoint or an amendment to the report backend
decision in ADR 0004.

The owner's WS-Maps `src/makemap.js` instead uses the website's location search,
daily forecast and warnings endpoints under `api.weather.bom.gov.au/v1`.
An observed `locations?search=Paluma` response returned Paluma, QLD 4816,
geohash `rhxgz59`, but its metadata explicitly restricted API use/copy/sharing.
Do not copy that integration into this app merely because its response is JSON.
The recorded permission concerns BOM data; scope for this API has not been
established. Prefer the documented data-product route or an endpoint explicitly
covered by the owner's permission.

## Paluma coverage remains a selection constraint

The successfully fetched QLD XML had issue time `2026-10-29T10:45:40Z` and SHA-256
`b0a1381d5e0b851817d7f382f5e7d1b5cafe7a5803659c0897966171099ccfd7`.
It contained **Ingham (`QLD_PT100`) and Townsville (`QLD_PT022`), but no area
named Paluma**. This is evidence from one feed issue, not a permanent coverage
guarantee. No full forecast payload is redistributed with this investigation.

Do not select the first nearby town silently or relabel its forecast “Paluma”.
For #39, either obtain an authorised product covering the Paluma coordinates
(for example an appropriate forecast-grid product), or explicitly approve and
label a regional substitute by its actual forecast location. The latter is
regional planning context, not a site-specific mountain forecast. The authorised
endpoint/location and operational owner remain unresolved configuration inputs.

## Terms and attribution

The [data services page](https://www.bom.gov.au/resources/data-services) describes
free and paid products. The [anonymous product terms](https://www.bom.gov.au/catalogue/anon-ftp.shtml)
do not grant general public redistribution. The
[weather data services guidance](https://www.bom.gov.au/catalogue/data-feeds.shtml)
also warns that anonymous access has no guaranteed availability or direct
service-change notification. Preserve the owner's separate permission record;
public access alone is not evidence of an open licence.

Use “Forecast: Bureau of Meteorology” with an official source link and the
forecast's actual location. Keep issue time distinct from app fetch time.
Final contractual credit wording and cache/redistribution terms must follow the
permission for the chosen product; a developer-chosen TTL is not a licensing
term. Do not reuse BOM logos or icon artwork without establishing their terms.
Text labels or project-owned icons avoid making that a weather-data dependency.

## Proposed contract and cache behaviour for #39

- Return product ID, location name/identifier/coordinates, official source URL,
  provider issue time, adapter fetch time, coverage periods and optional daily
  values. Keep provenance when normalising. Use ISO 8601 timestamps with offsets
  or UTC; render Paluma dates in AEST (UTC+10).
- Each period carries start/end instants. Fields can be absent, especially the
  first/partial day: the inspected Ingham period zero had no temperature or rain
  amount. Missing is not zero. Keep rain ranges and probabilities faithful to
  the source; do not invent a single rainfall value from a range.
- Persist the last validated successful response. A timeout, malformed XML/JSON,
  unexpected location, out-of-order issue time or failed write must leave the
  last good cache available. Validate the complete replacement before activation.
- Show provider issue time and **fetched at** even when online. Offline/failed
  refresh must be explicit. When there is no cache, show unavailable; never an
  empty card that resembles a clear forecast. Expired periods must not be shown
  as current, and no forecast means no assertion of safe weather.
- A suggested initial refresh interval is six hours, configurable and subject to
  the approved feed terms. Back off on failures and honour data preferences.
  Staleness must also consider provider issue time and period coverage: fetching
  an old upstream document does not make it fresh. No perpetual background
  execution is promised on either mobile or web.
- Weather failure must not prevent map/planner/POI use. Warnings and QPWS
  closures are separate products/features; an ordinary forecast or empty
  warnings response must not be treated as a park-open or all-clear signal.

Before merging #39, use synthetic fixtures for partial/missing fields,
timezone/weekend boundaries, expired coverage, offline restart, corrupt cache,
refresh failure and retention of last good data. Verify Android and web transport
against the authorised HTTPS endpoint and show unavailable/stale states in the
four theme/text-size previews. This investigation does not claim those checks
have already passed.
