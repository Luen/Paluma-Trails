# Emergency contact correction — 30 October 2026

Issue #124 concerns the emergency-contact wording, not a complete review of
every safety topic in the app.

The previous instruction said to send an SMS when a call could not connect,
without naming a recipient. Beside the 000/112 call buttons, this could imply
that those numbers accept ordinary SMS. That instruction has been removed.

- [ACMA: Emergency calls](https://www.acma.gov.au/emergency-calls), especially
  Network coverage and Text messages: ordinary texts cannot be sent directly
  to 000/112; a call over a mobile network needs available mobile coverage.
- [Australian Government: Using other emergency numbers](https://www.infrastructure.gov.au/media-communications/phone/triple-zero/using-other-emergency-numbers):
  112 reaches the same service as 000 and does not create mobile reception.
  Its discussion of NRS relay services is distinct from direct SMS to an
  emergency number. This app does not implement an emergency relay service.
- [Australian Government: How to call Triple Zero](https://www.infrastructure.gov.au/media-communications/phone/triple-zero/how-call-triple-zero-000):
  provide location information, follow the operator's instructions and seek
  available help if unable to connect. No SMS-delivery guarantee is inferred.

All three were read on 30 October 2026 (Australia/Brisbane). The app uses
original summaries, with offline-readable reference labels and optional online
source links. No agency endorsement is implied. The wording explicitly concerns
calls over a mobile network; it does not claim to document every satellite,
VoIP or accessibility-relay option.

Source content, schema, bundle and printable map were regenerated together.
The regression test reads the actual bundled safety JSON, checks the direct-SMS
and coverage clarification, and renders it with location off. Test call actions
use fakes; no real emergency calls were placed during review.
