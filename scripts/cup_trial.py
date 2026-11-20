"""Run one counterbalanced session on private copies of the Continental Cup catalogue."""
import argparse
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
from urllib.request import Request, urlopen

from event_studio import load, validate

TASKS = {"A": (128, [55, 70, 85]), "B": (164, [75, 90, 100])}
ORDERS = [(("A", "manual"), ("B", "agent")), (("A", "agent"), ("B", "manual")),
          (("B", "manual"), ("A", "agent")), (("B", "agent"), ("A", "manual"))]


def store(path, data):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path)


def read(path):
    return json.loads(path.read_text())


def brief(task):
    goal_cash, options = TASKS[task]
    return (f"Set the cash reward for a goal to {goal_cash}. From {options}, choose the lowest guaranteed "
            "payout between the expected shot cash and expected total value (cash plus trophy). "
            "Keep every other catalogue field unchanged. Check the outcome and accept or edit the draft.")


def draft(base, task, payout):
    changed = deepcopy(base)
    next(s for s in changed["shots"] if s["result"] == "goal")["cash"] = TASKS[task][0]
    changed["safe_cash"] = payout
    return changed


def check(base, task, submitted):
    validate(submitted)
    payout = submitted["safe_cash"]
    if submitted != draft(base, task, payout):
        raise ValueError("Check the requested goal reward and restore unrelated fields")
    for candidate in TASKS[task][1]:
        try:
            validate(draft(base, task, candidate))
        except ValueError:
            continue
        if payout != candidate:
            raise ValueError("Choose the smallest qualifying payout from the task")
        return
    raise ValueError("No qualifying payout in this task")


def suggest(base, task, endpoint, previous):
    rejected = {item["payout"]: item["review"] for item in previous if item["review"] != "accepted"}
    options = [option for option in TASKS[task][1] if option not in rejected]
    if not options:
        raise ValueError("All available proposals were rejected; inspect the draft manually")
    prompt = {"task": brief(task), "shots": base["shots"], "trophy_value": base["trophy_value"],
              "previous_verdicts": rejected, "remaining_options": options}
    schema = {"type": "object", "properties": {"payout": {"type": "integer", "enum": options}},
              "required": ["payout"], "additionalProperties": False}
    body = {"model": "qwen", "temperature": 0, "seed": 42, "max_tokens": 40,
            "messages": [{"role": "user", "content": json.dumps(prompt)}],
            "response_format": {"type": "json_schema", "json_schema": {"name": "offer", "schema": schema}}}
    req = Request(endpoint + "/v1/chat/completions", json.dumps(body).encode(),
                  headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=60) as res:
        result = json.load(res)
    payout = json.loads(result["choices"][0]["message"]["content"])["payout"]
    if type(payout) is not int or payout not in options:
        raise ValueError("Model returned a payout outside the task options")
    return draft(base, task, payout), result["usage"]["total_tokens"]


def summarize(folders):
    results = []
    numbers = set()
    for folder in folders:
        state = read(folder / "session.json")
        if state["source"] != "human":
            continue
        number = state["number"]
        if number in numbers:
            raise ValueError(f"Duplicate participant number {number} in this comparison")
        numbers.add(number)
        row = {"participant": number, "tasks": []}
        times = {}
        for task in state["rounds"]:
            elapsed = task.get("elapsed_seconds")
            row["tasks"].append({"task": task["task"], "mode": task["mode"], "seconds": elapsed,
                "accepted": elapsed is not None, "rejections": sum(not a["accepted"] for a in task["submissions"]),
                "human_edits": task.get("human_edits"), "observation": task.get("observation")})
            if elapsed is not None:
                times[task["mode"]] = elapsed
        if set(times) == {"manual", "agent"}:
            row["manual_minus_agent_seconds"] = round(times["manual"] - times["agent"], 2)
        results.append(row)
    return {"participants": len(results), "sessions": results}


def main(args):
    if args.action == "summary":
        print(json.dumps(summarize(args.sessions), indent=2, ensure_ascii=False))
        return
    folder = args.session
    state_file = folder / "session.json"
    if args.action == "init":
        folder.mkdir(parents=True, exist_ok=False)
        base, _ = load()
        store(folder/"baseline.json", base)
        store(state_file, {"source": args.source, "number": args.number, "rounds": [],
                           "baseline_sha256": hashlib.sha256((folder/"baseline.json").read_bytes()).hexdigest(),
                           "created_utc": datetime.now(timezone.utc).isoformat()})
        return
    state = read(state_file)
    rounds = state["rounds"]
    base = read(folder/"baseline.json")
    if args.action == "start":
        if len(rounds) == 2 or (rounds and "elapsed_seconds" not in rounds[-1]):
            raise ValueError("Finish the active task or start a new session for a retest")
        task, mode = ORDERS[(state["number"] - 1) % len(ORDERS)][len(rounds)]
        store(folder/f"{task}-draft.json", base)
        rounds.append({"task": task, "mode": mode, "started": time.time(), "submissions": [], "suggestions": []})
        store(state_file, state)
        print(mode, brief(task), folder/f"{task}-draft.json", sep="\n")
        return
    if args.action == "note":
        if not rounds or args.edits < 0:
            raise ValueError("Start a task first and enter a nonnegative edit count")
        rounds[-1].update(human_edits=args.edits, observation=args.text)
        store(state_file, state)
        return
    if not rounds or "elapsed_seconds" in rounds[-1]:
        raise ValueError("Start the next task first")
    current = rounds[-1]
    task = current["task"]
    path = folder/f"{task}-draft.json"
    suggestion = folder/f"{task}-suggested.json"
    if args.action == "assist":
        if current["mode"] != "agent":
            raise ValueError("Agent assistance is available only in the assisted round")
        proposed, tokens = suggest(base, task, args.endpoint, current["suggestions"])
        try:
            check(base, task, proposed)
            review = "accepted"
        except ValueError as error:
            review = str(error)
        store(suggestion, proposed)
        current["suggestions"].append({"payout": proposed["safe_cash"], "tokens": tokens, "review": review})
        print("Proposed payout:", proposed["safe_cash"], "| Verifier:", review, "| Draft:", suggestion)
    else:
        if args.suggested:
            if current["mode"] != "agent" or not current["suggestions"]:
                raise ValueError("No model suggestion in this round")
            path = suggestion
        if current["mode"] == "agent" and not current["suggestions"]:
            raise ValueError("Request and inspect the model proposal before submitting the assisted task")
        try:
            check(base, task, read(path))
        except (ValueError, KeyError, TypeError) as error:
            current["submissions"].append({"accepted": False, "reason": str(error)})
            store(state_file, state)
            raise
        current["submissions"].append({"accepted": True})
        current["elapsed_seconds"] = round(time.time() - current["started"], 2)
        store(folder/f"{task}-accepted.json", read(path))
        print("Accepted in", current["elapsed_seconds"], "seconds")
    store(state_file, state)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    summary = commands.add_parser("summary")
    summary.add_argument("sessions", nargs="+", type=Path)
    for name in ("init", "start", "assist", "submit", "note"):
        cmd = commands.add_parser(name)
        cmd.add_argument("session", type=Path)
        if name == "note":
            cmd.add_argument("--edits", type=int, required=True)
            cmd.add_argument("--text", required=True)
        if name == "init":
            cmd.add_argument("--number", type=int, required=True, choices=range(1, 100))
            cmd.add_argument("--source", choices=("human", "smoke"), required=True)
        if name == "assist":
            cmd.add_argument("--endpoint", default="http://127.0.0.1:18181")
        if name == "submit":
            cmd.add_argument("--suggested", action="store_true")
    try:
        main(parser.parse_args())
    except (ValueError, OSError) as error:
        parser.exit(1, f"{error}\n")
