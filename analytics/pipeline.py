"""Validate JSONL, build checked SQLite marts and export a reproducible analyst report."""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import math
from pathlib import Path
import sqlite3
import tempfile

HERE = Path(__file__).resolve().parent
COLUMNS = ("event_id", "dataset", "player_id", "session_id", "ts", "variant", "device", "channel", "mode", "name", "value")
COHORT_DATASETS = {"synthetic_ab", "playtest"}
COHORT_EVENTS = {"OnboardingAssigned_v1", "FirstRouteSeconds_v2", "ClubSigned_v1", "SeasonFinished_v1",
                 "SeasonReplayed_v1", "SessionJoined", "AuctionWon_v1", "AssetSigned_v1"}
ECONOMY_EVENTS = {"TableDecisions", "TableFees", "TableKickoffAwards", "TableCupVisits", "TableGoals",
                  "EndingCash", "EndingValue", "OwnedClubs", "StadiumUpgrades", "CupsWon",
                  "TableAuctions", "TableAuctionSales"}
DIMENSIONS = {
    "synthetic_ab": ({"control", "coach"}, {"mobile", "desktop", "unknown"}, {"direct", "friend", "campaign", "unknown"}, {"solo"}),
    "rules_simulation": ({"none"}, {"none"}, {"none"}, set("23456")),
}
DIMENSIONS["playtest"] = DIMENSIONS["synthetic_ab"]


def checked_events(path):
    events, duplicates = {}, 0
    for number, line in enumerate(path.read_text().splitlines(), 1):
        try:
            row = json.loads(line)
            if not isinstance(row, dict) or set(row) != set(COLUMNS):
                raise ValueError("incorrect event columns")
            for key in ("event_id", "player_id", "session_id"):
                if not isinstance(row[key], str) or not 1 <= len(row[key]) <= 80:
                    raise ValueError("invalid key")
            if type(row["ts"]) is not int or row["ts"] < 1:
                raise ValueError("invalid Unix timestamp")
            value = row["value"]
            if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                raise ValueError("invalid numeric value")
            dataset = row["dataset"]
            if not isinstance(dataset, str) or dataset not in DIMENSIONS:
                raise ValueError("invalid dataset")
            for column, permitted in zip(("variant", "device", "channel", "mode"), DIMENSIONS[dataset]):
                if not isinstance(row[column], str) or row[column] not in permitted:
                    raise ValueError(f"invalid {column}")
            names = COHORT_EVENTS if dataset in COHORT_DATASETS else ECONOMY_EVENTS
            if not isinstance(row["name"], str) or row["name"] not in names:
                raise ValueError("event name outside the contract")
            event_id = row["event_id"]
            if event_id in events:
                if row != events[event_id]:
                    raise ValueError("duplicate event id with conflicting payload")
                duplicates += 1
                continue
            events[event_id] = row
        except ValueError as exc:
            raise ValueError(f"{path.name}:{number}: {exc}") from exc
    if not events:
        raise ValueError("empty dataset")
    return list(events.values()), duplicates


def wilson(success, n):
    z = 1.9599639845
    p = success / n
    denominator = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denominator
    radius = z / denominator * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return center - radius, center + radius


def compare(control, coach, counter):
    a, b = control[counter], coach[counter]
    n, m = control["players"], coach["players"]
    pa, pb = a / n, b / m
    al, ah = wilson(a, n)
    bl, bh = wilson(b, m)
    delta = pb - pa
    # Newcombe interval for two independent proportions.
    lo = delta - math.hypot(pb - bl, ah - pa)
    hi = delta + math.hypot(bh - pb, pa - al)
    return {"control": pa, "coach": pb, "delta": delta, "ci95_lower": lo, "ci95_upper": hi}


def experiment(segments, dataset):
    arms = {r["variant"]: r for r in segments if r["dimension"] == "all"}
    if set(arms) != {"control", "coach"}:
        raise ValueError("experiment requires both arms")
    control, coach = arms["control"], arms["coach"]
    n, m = control["players"], coach["players"]
    srm_p = math.erfc(abs(n - m) / math.sqrt(2 * (n + m)))
    primary = compare(control, coach, "routes")
    guardrail = compare(control, coach, "finishing")
    baseline, target, average = .65, .70, .675
    minimum = math.ceil(((1.96 * math.sqrt(2 * average * (1 - average))
                           + .8416 * math.sqrt(baseline * (1 - baseline) + target * (1 - target))) / (target - baseline)) ** 2)
    guardrail_minimum = math.ceil(2 * .64 * .36 * (1.96 + .8416) ** 2 / .03 ** 2)
    if srm_p < .01:
        decision = "investigate_allocation"
    elif min(n, m) < minimum:
        decision = "collect_more"
    elif primary["ci95_lower"] <= 0:
        decision = "hold_primary"
    elif min(n, m) < guardrail_minimum or guardrail["ci95_lower"] <= -.03:
        decision = "hold_guardrail"
    else:
        decision = "gates_pass"
    return {"dataset": dataset, "control_players": n, "coach_players": m, "srm_p": srm_p,
            "minimum_per_arm": minimum, "guardrail_minimum_per_arm": guardrail_minimum, "first_route_within_90s": primary, "finish_guardrail": guardrail,
            "decision": decision}


def write_csv(path, rows):
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def dashboard(out, readout, segments, economy):
    primary = readout["first_route_within_90s"]
    guardrail = readout["finish_guardrail"]
    def table(rows):
        header = "".join("<th>" + html.escape(title.replace("_", " ").title()) + "</th>" for title in rows[0])
        body = "".join("<tr>" + "".join(f"<td>{html.escape(str(v))}</td>" for v in row.values()) + "</tr>" for row in rows)
        return f"<table><thead><tr>{header}</tr></thead><tbody>{body}</tbody></table>"
    segment_rows = []
    for row in segments:
        n = row["players"]
        segment_rows.append({"dimension": row["dimension"], "segment": row["segment"], "variant": row["variant"],
                             "players": n, "route 90s": f"{row['routes']/n:.1%}", "signed": f"{row['signing']/n:.1%}",
                             "finished": f"{row['finishing']/n:.1%}", "replayed": f"{row['replaying']/n:.1%}",
                             "d1 eligible": row["d1_eligible"],
                             "d1": f"{row['d1_returned']/row['d1_eligible']:.1%}" if row["d1_eligible"] else "—"})
    def delta(label, metrics):
        return (f"<article><h2>{label}</h2><strong>{metrics['delta'] * 100:+.2f} pp</strong>"
                f"<p>95% CI {metrics['ci95_lower']*100:+.2f} to {metrics['ci95_upper']*100:+.2f} pp</p></article>")
    outcome = {"gates_pass": "Both statistical gates pass", "hold_guardrail": "Completion guardrail inconclusive",
               "hold_primary": "First route improvement inconclusive", "collect_more": "Sample too small",
               "investigate_allocation": "Investigate the arm allocation"}[readout["decision"]]
    data_label = "Synthetic onboarding fixture" if readout["dataset"] == "synthetic_ab" else "Closed playtest"
    followup = "Collect live assignments before choosing what to ship." if readout["dataset"] == "synthetic_ab" else "Review data quality and platform coverage before a rollout decision."
    page = f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Soccerpoly product analysis</title>
<style>
*{{box-sizing:border-box}}body{{font:16px system-ui;color:#eaf1f8;background:#101c2a;margin:0}}main{{max-width:1180px;margin:auto;padding:clamp(20px,5vw,65px)}}h1{{font-size:clamp(2rem,5vw,3.8rem);line-height:1.05;margin:.35em 0}}h2{{font-size:1.15rem}}p,small{{color:#bacadc;line-height:1.52}}strong{{font-size:2rem;color:#c4ff87}}section{{margin-top:34px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:14px}}article{{background:#172a3e;border:1px solid #30506a;padding:10px 19px;border-radius:10px}}.scroller{{overflow:auto}}table{{width:100%;border-collapse:collapse;text-align:left;font-variant-numeric:tabular-nums;font-size:.86rem}}th,td{{padding:.65rem;border-bottom:1px solid #345069;white-space:nowrap}}th{{color:#9fd7fa}}input,select{{padding:.5rem;margin:.5rem;color:#edf4ff;background:#203752;border:1px solid #63849e;border-radius:5px}}
</style>
<main><small>SOCCERPOLY · CONTINENTAL CUP</small><h1>Coach hint experiment</h1>
<p>{data_label}. {readout['control_players']:,} control and {readout['coach_players']:,} coach assignments.
Planned per arm: {readout['minimum_per_arm']:,} for the primary metric and {readout['guardrail_minimum_per_arm']:,} for completion. Allocation p = {readout['srm_p']:.3f}.</p>
<div class="grid">{delta("First route within 90 seconds",primary)}{delta("Season completion",guardrail)}
<article><h2>Decision gate</h2><p>{outcome}. {followup}</p></article></div>
<section><h2>Onboarding by device and acquisition channel</h2>
<label>Breakdown <select id="segment"><option value="all">Overall</option><option value="device">Device</option><option value="channel">Channel</option></select></label>
<div class="scroller" id="bySegment">{table(segment_rows)}</div></section>
<section><h2>In-game economy</h2><p>1,200 deterministic bot seasons using the Roblox rules. Each row represents one table size.</p>
<div class="scroller">{table(economy)}</div></section></main>
<script>const select = document.querySelector('#segment');
function filter(){{document.querySelectorAll('#bySegment tbody tr').forEach(row => row.hidden = row.cells[0].textContent !== select.value);}}
select.addEventListener('change',filter); filter();</script></html>"""
    out.write_text(page)


def run(source, out, cohort_dataset="synthetic_ab"):
    events, duplicates = checked_events(source)
    out.mkdir(parents=True, exist_ok=True)
    schema = (HERE / "metrics.sql").read_text()
    with tempfile.TemporaryDirectory(dir=out) as folder:
        stage = Path(folder)
        database = stage / "worlddraft.sqlite"
        with sqlite3.connect(database) as conn:
            conn.row_factory = sqlite3.Row
            conn.execute("""CREATE TABLE events (
                event_id TEXT PRIMARY KEY, dataset TEXT NOT NULL, player_id TEXT NOT NULL, session_id TEXT NOT NULL,
                ts INTEGER NOT NULL, variant TEXT NOT NULL, device TEXT NOT NULL, channel TEXT NOT NULL,
                mode TEXT NOT NULL, name TEXT NOT NULL, value REAL NOT NULL)""")
            conn.executemany("INSERT INTO events VALUES (" + ",".join("?" * len(COLUMNS)) + ")",
                             [tuple(event[column] for column in COLUMNS) for event in events])
            conn.execute("CREATE INDEX player_time ON events(dataset, player_id, ts)")
            conn.execute("CREATE TABLE analysis_config (cohort_dataset TEXT NOT NULL)")
            conn.execute("INSERT INTO analysis_config VALUES (?)", (cohort_dataset,))
            conflict = conn.execute("""SELECT player_id FROM events WHERE dataset = ? AND name = 'OnboardingAssigned_v1'
                GROUP BY player_id HAVING COUNT(DISTINCT variant) > 1 LIMIT 1""", (cohort_dataset,)).fetchone()
            if conflict:
                raise ValueError("Experiment assignment drift: a player is in both arms")
            conn.executescript(schema)
            segments = [dict(row) for row in conn.execute("SELECT * FROM segment_metrics ORDER BY dimension, segment, variant")]
            economy = [dict(row) for row in conn.execute("SELECT * FROM economy ORDER BY seats")]
        report = experiment(segments, cohort_dataset)
        if len(economy) != 5 or any(row["tables"] < 1 for row in economy):
            raise ValueError("expected economy coverage for all five table sizes")
        write_csv(stage / "segments.csv", segments)
        write_csv(stage / "economy.csv", economy)
        (stage / "experiment.json").write_text(json.dumps(report, indent=2) + "\n")
        (stage / "lineage.json").write_text(json.dumps({
            "source": source.name, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "accepted": len(events), "duplicates_removed": duplicates, "quality": "passed",
            "marts": {"segments.csv": "events → assigned → player_outcomes → segment_metrics",
                      "economy.csv": "events (rules_simulation) → economy"},
        }, indent=2) + "\n")
        dashboard(stage / "index.html", report, segments, economy)
        for product in stage.iterdir():
            product.replace(out / product.name)
    return report


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("--events", type=Path, required=True)
    cli.add_argument("--out", type=Path, default=Path("dist/analytics"))
    cli.add_argument("--cohort-dataset", choices=sorted(COHORT_DATASETS), default="synthetic_ab")
    opts = cli.parse_args()
    report = run(opts.events, opts.out, opts.cohort_dataset)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
