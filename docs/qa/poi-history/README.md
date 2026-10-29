# Historic POI photo review

The screenshots show the actual Flutter `PoiPhotoCard` with the bundled 1911
Johnstone's hut image, using the project's theme. They are component previews,
not a claim of field/device testing or present-day site conditions.

- [Light and dark](light-dark.jpg): photograph, caption, book/collection credit
  and permission text wrap inside the 360 px preview.
- [Sunlight and large text](sunlight-large.jpg): captions and attribution remain
  readable at 2× text scale; the card scrolls when it exceeds the viewport.

`app/lib/previews.dart` provides the four previews. The regression tests also
load the real packaged photo at 360 px width, check caption/credit semantics,
scroll to the licence, and verify that unreadable images leave text accessible.
No controls or touch targets were added. Brand contrast checks pass. Photos use
`BoxFit.contain`, retaining the complete source photograph crop on screen.
