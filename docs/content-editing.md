# Contributing a content correction

You can suggest a correction without installing Flutter, editing JSON or running
a build. Use the **Content correction** form in this repository's
[issue chooser](https://github.com/Luen/Paluma-Trails/issues/new/choose).
A maintainer reviews the evidence, edits the source files, builds the offline
bundle and opens a PR. The chosen workflow is recorded in
[ADR 0008](decisions/0008-content-editing.md) (#13).

## What to include

Name the place or track and, if possible, copy its ID from
`content/data/paluma/pois.json`, `junctions.json` or `tracks.geojson`. If you do
not know the ID, use its displayed name or junction number and enough detail to
distinguish it. State what the app says now and exactly what should replace it.

For example, a useful request identifies the POI, quotes the current sentence,
gives replacement wording, and cites a book with page number or a source URL.
An unpublished observation needs its observation date, how it was established,
and permission to use it. If the evidence is uncertain, say so; the maintainer
can keep it marked `unverified`. Do not present a signal icon as verified phone
reception or a personal observation as an official closure notice.

For a location correction, give WGS84 decimal latitude and longitude in separate,
labelled fields. JSON uses `lat` and `lon`; GeoJSON uses `[longitude, latitude]`.
Include the measurement method and uncertainty. A map screenshot alone may be
useful context but is not proof of a surveyed location.

For photos, include the creator, permission/licence and caption, and say whether
the project may redistribute the image offline. Do not upload an image you do
not have permission to share. Historic photo rights remain tracked in #28;
photo packaging/rendering is separate from a text correction. Avoid private
contact details, personal location histories and identifiable bystanders in
public issues. Submit only the evidence needed for the correction.

The form is for the app's reference content. To request track clearing, use the
maintenance contact in the issue chooser; filing a content correction is not a
promise that a maintenance team or emergency service will see it.

## If you prefer to edit the file yourself

Start a branch from `dev`, edit only the relevant source JSON under
`content/data/paluma/`, and submit a PR back to `dev`. A maintainer can help with
the generated bundle before merge. Do not change an existing `id` or `qr_id`:
physical signs and references may depend on it. Do not edit generated files
under `app/assets/bundle/` or `segments.json` by hand.

For a simple text correction, preserve the surrounding object and edit `name`,
`summary` or `description` as appropriate. JSON text uses double quotes; a quote
inside a value is written `\"`, and a line break inside a value is `\n`. Keep the
existing commas and brackets. Use the existing category values rather than
inventing a new one. A new source for a POI belongs in its `sources` list as a
`label` with an optional `url`; the `source` field is the provenance identifier.
See [the content model](content-model.md) and the schemas under `content/schema/`
for larger changes. Ask for help in the issue if the JSON is unfamiliar.

## Maintainer handoff

1. Check the proposed facts, evidence, permission and location uncertainty.
   Preserve IDs and do not clear `unverified` without adequate verification.
2. Apply the smallest source edit. Record provenance in `sources.json` when
   adding a source, and retain POI citations alongside the affected text.
3. Update `park.updated`, regenerate the graph if geometry/junctions changed,
   then validate and rebuild the bundle using the existing CLI.
4. Open or update a PR to `dev` linking the request, including the generated
   bundle diff, checks and offline inspection. Tell the contributor the result
   in that PR/issue when reviewing it; merging an edit does not instantly
   replace the bundle installed on walkers' phones.
5. Deliver the next app/web release using [the release guide](release.md).

CI checks schema shape, duplicate IDs, graph references and bundle freshness.
It does not establish historical truth, land-manager endorsement, image rights
or field accuracy; those require human review. A malformed JSON edit may fail
before schema errors can be listed. Fix the indicated file and rerun validation
rather than bypassing CI.

No spreadsheet import or external CMS is deployed. If contributions grow enough
to justify one, revisit ADR 0008 with a proposal that preserves stable IDs,
reviewable source changes, provenance and offline bundle generation.
