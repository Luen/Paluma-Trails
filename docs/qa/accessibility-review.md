# Accessibility review — 29 October 2026

This is the repository-based portion of #53. Physical track accessibility and
real TalkBack/VoiceOver sessions remain field/device work, not inferred passes.

## Change made

Custom map controls now expose a named button role, enabled state and tap action
to assistive technology. Their existing tooltip is the accessible name. Child
icon/tooltip semantics are excluded to avoid duplicate announcements. The visual
48 dp control and pointer handling are unchanged.

## Automated evidence

- `planner_accessibility_test.dart` drives one-way/out-and-back/loop selection
  at 320 px with 2× text, checks for layout exceptions, and runs Flutter's
  labelled-target and Android 48 dp target guidelines.
- The same test verifies the custom map control's name, button role, enabled
  state and tap action, rather than relying on an icon being recognised.
- Existing location-overlay tests check 48 dp controls and tap handling;
  existing POI-photo tests check narrow/large-text captions and attribution.
- `tools/brand/colour_check.py` checks the documented brand text contrast and map
  feature contrast/differentiation. The palette and typography are unchanged.

## Follow-up before declaring launch accessibility complete

Run the field-test plan in light, dark and sunlight modes on physical phones,
with TalkBack and VoiceOver enabled. Check reading/focus order, map gestures,
permission prompts, source/photo text and the emergency flow. Record device and
OS versions, defects and retests. Automated semantic checks cannot establish
that an entire screen is pleasant or practical to use with a screen reader.

Track surface, steps, slope, obstacles and accessible facilities need sourced
on-site information. Do not label tracks wheelchair-accessible or inaccessible
from this software review, route distances or missing elevation data. Keep
those content assessments open under #53 until evidence is collected.
