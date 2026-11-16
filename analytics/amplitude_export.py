"""Write an offline Amplitude HTTP V2 event sample from the synthetic cohort."""
import argparse
import json
from pathlib import Path

from pipeline import checked_events


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--events", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    events, _ = checked_events(args.events)
    cohort = [row for row in events if row["dataset"] == "synthetic_ab"]
    first_seen = {}
    for row in cohort:
        key = row["player_id"], row["session_id"]
        first_seen[key] = min(first_seen.get(key, row["ts"]), row["ts"])
    payload = []
    for row in cohort[:25]:
        key = row["player_id"], row["session_id"]
        payload.append({
            "user_id": "worlddraft-fixture-" + row["player_id"],
            "session_id": first_seen[key] * 1000,
            "event_type": row["name"],
            "time": row["ts"] * 1000,
            "insert_id": "worlddraft-fixture-" + row["event_id"],
            "event_properties": {key: row[key] for key in ("dataset", "variant", "device", "channel", "mode", "value")},
        })
    if not payload:
        raise ValueError("no synthetic cohort data")
    args.out.write_text(json.dumps({"events": payload}, indent=2) + "\n")
    print(f"Wrote {len(payload)} synthetic event payloads for review")


if __name__ == "__main__":
    main()
