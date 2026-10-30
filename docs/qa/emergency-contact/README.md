# Emergency contact guidance QA

Reviewed 30 October 2026. `guidance.png` shows the release web build on a fresh
local origin, bundle `2026-10-30-0a933125`, with location off. The emergency call
buttons remain above the instructions. The first instruction explicitly rules
out direct SMS to 000/112; the coverage qualification is visible below it.
Scrolled to the three official source labels and their explicit “Read online”
actions. No emergency call, GPS permission or external source action was invoked.

The actual bundled safety content is exercised by `safety_content_test.dart`,
including 320 px light, dark, sunlight and 2× text layouts. These checks verify
rendering and offline source labels; they do not establish device reception or
review every other safety topic. App analysis, 179 tests and release web build
passed before integration with the walk-preview branch.
