# /// script
# requires-python = ">=3.11"
# dependencies = ["sentry-sdk==2.57.0"]
# ///
"""Exercise Sentry routing with an in-memory transport and a rejected draft."""
from copy import deepcopy

import sentry_sdk
from sentry_sdk.transport import Transport

from event_studio import load, validate


class InMemoryTransport(Transport):
    def __init__(self):
        super().__init__()
        self.envelopes = []

    def capture_envelope(self, envelope):
        self.envelopes.append(envelope)


edition, _ = load()
broken = deepcopy(edition)
broken["shots"][0]["weight"] = 9
sink = InMemoryTransport()
sentry_sdk.init(transport=sink, default_integrations=False, release=edition["id"], send_default_pii=False)
with sentry_sdk.new_scope() as scope:
    scope.set_tag("stage", "event_catalog_validation")
    try:
        validate(broken)
    except ValueError:
        sentry_sdk.capture_message("Invalid Continental Cup catalogue rejected", "warning")
sentry_sdk.flush(timeout=1)
assert len(sink.envelopes) == 1
event = sink.envelopes[0].get_event()
assert event["release"] == edition["id"] and event["tags"]["stage"] == "event_catalog_validation"
print("Sentry SDK: invalid draft reported to the in-memory transport")
