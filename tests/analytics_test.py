import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("worlddraft_pipeline", ROOT / "analytics/pipeline.py")
assert spec and spec.loader
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)


class AnalyticsTest(unittest.TestCase):
    def test_window_and_duplicate(self):
        common = dict(dataset="synthetic_ab", player_id="p1", session_id="s1", ts=1000,
                      variant="control", device="mobile", channel="direct", mode="solo", value=1)
        assignment = dict(common, event_id="a", name="OnboardingAssigned_v1")
        late = dict(common, event_id="b", name="FirstRouteSeconds_v2", ts=1090)
        other_session = dict(common, event_id="c", name="FirstRouteSeconds_v2", ts=1020, session_id="s2")
        replay = dict(common, event_id="d", name="OnboardingAssigned_v1", ts=2000, session_id="s3")
        with tempfile.TemporaryDirectory() as work:
            file = Path(work) / "events.jsonl"
            file.write_text("\n".join(map(json.dumps, [assignment, late, assignment, other_session, replay])))
            events, duplicate = pipeline.checked_events(file)
            self.assertEqual((len(events), duplicate), (4, 1))
            with sqlite3.connect(":memory:") as db:
                db.execute("CREATE TABLE events (" + ",".join(pipeline.COLUMNS) + ")")
                db.execute("CREATE TABLE analysis_config AS SELECT 'synthetic_ab' AS cohort_dataset")
                db.executemany("INSERT INTO events VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                               [tuple(event[col] for col in pipeline.COLUMNS) for event in events])
                db.executescript((ROOT / "analytics/metrics.sql").read_text())
                self.assertEqual(db.execute("SELECT players, routes FROM segment_metrics WHERE dimension='all'").fetchone(), (1, 0))
                early = dict(common, event_id="e", name="FirstRouteSeconds_v2", ts=1089)
                db.execute("INSERT INTO events VALUES (?,?,?,?,?,?,?,?,?,?,?)", tuple(early[col] for col in pipeline.COLUMNS))
                self.assertEqual(db.execute("SELECT routes FROM segment_metrics WHERE dimension='all'").fetchone(), (1,))

    def test_statistical_gates(self):
        def cohort(arm, n, routes):
            return {"dimension": "all", "variant": arm, "players": n, "routes": routes, "finishing": int(n * .64)}
        small = [cohort("control", 1800, 1170), cohort("coach", 1800, 1334)]
        self.assertEqual(pipeline.experiment(small, "synthetic_ab")["decision"], "hold_guardrail")
        large = [cohort("control", 5000, 3250), cohort("coach", 5000, 3500)]
        self.assertEqual(pipeline.experiment(large, "synthetic_ab")["decision"], "gates_pass")
        mismatch = [cohort("control", 5000, 3250), cohort("coach", 6000, 4200)]
        self.assertEqual(pipeline.experiment(mismatch, "synthetic_ab")["decision"], "investigate_allocation")


if __name__ == "__main__":
    unittest.main()
