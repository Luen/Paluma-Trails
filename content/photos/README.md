# Paluma history photographs

Credit: *Paluma: The First Eighty Years 1870s–1950s*.
Author: Linda Venn. Published by Thuringowa City Council, February 2002.
Copyright holder: Thuringowa City Council; rights now administered under
Townsville City Council following local government amalgamations.

## Permission record

On 2026-10-29 the repository owner, Luen Warneke, confirmed that permission
was given to **Luen Warneke of Wanderstories to use all wording and photographs**
from this book. The confirmation was supplied during the content contribution
review, after the book's copyright notice was checked. This records the owner's
confirmation; a separate permission instrument is not stored in the public repo.
No Creative Commons, public-domain or onward-redistribution licence is claimed.
Original copyright and collection credits are retained.

## Extraction and attribution

The four book JPEGs are photographic crops from the community-hosted reading copy,
rendered at 180 dpi, resized to at most 1200 px wide and JPEG-compressed at
quality 88. Captions and page text were excluded from the crop; equivalent
credits/captions are stored in `content/data/paluma/pois.json`. No colourisation,
generative reconstruction or removal of photographic content was performed.
These four images depict historic scenes, not present conditions.

`catalogue.json` records the source PDF hash, each image hash, dimensions,
printed/PDF page number, crop bounds, matched POI and the book's original credit
for book images; web images instead record their source page and asset URLs.
Printed page numbers are two below PDF page numbers. See
[the research record](../research/paluma-history.md) for source URLs and limits
on matching the book's place names to modern markers.

No photograph of Garde’s hut or Shay’s guesthouse was identified in the book.
A separately sourced Wanderstories photograph of Garde’s Lookout is now included.
Johnstone's hut and Cavill's battery must not be relabelled as
Garde's sites. The Foxlee photograph is a party near the lookout, not a current
view from it.

The bundler copies only referenced image files into `app/assets/bundle/photos/`;
the catalogue and this permission record remain source documentation.

## Wanderstories permission and photograph

On 2026-10-29 Luen Warneke explicitly authorised use of photos, information and
wording from the Wanderstories Paluma guide and other Wanderstories pages for
this project. Original site and collection credits must still be retained;
material with an independent third-party credit is not treated as authored by
Wanderstories solely because it appears on the site.

`gardes-lookout-wanderstories.jpg` is the original JPEG from the Paluma guide,
unchanged. Its caption identifies Garde's Lookout; capture date and exact camera
position are not supplied. Credit: Wanderstories, *Paluma Range National Park
Trails*, by Luen Warneke and Wilfred Karnoll. The guide gives no separate
individual photographer credit for this image; no individual credit is invented.
The source URL, page, hash and processing record are in `catalogue.json`.
This permission does not extend the book permission to club photographs/maps.

See also the consolidated [source permission record](../research/source-permissions.md).

## Adding or replacing a photograph

Every photograph referenced by a POI must have a matching `file` + `poi_id`
entry in `catalogue.json`. Include its original caption/collection credit,
SHA-256 of the exact source bytes, source page or extraction details, and a
`permission_record` path relative to this directory. Permission records are
Markdown files kept inside `content/`; do not store private contact details or
credentials. The POI's offline photo still needs its own caption, credit and
licence/permission wording.

Content validation checks the catalogue, image hashes and permission-record
links before building a bundle. Replacing the image, assigning it to another
POI or removing its provenance record must be an explicit reviewed update.
The automated checks establish consistency, not the legal sufficiency of a
permission or the correct identification of a historical site. Those remain
part of the human content review. No new reuse licence is granted by this check.
