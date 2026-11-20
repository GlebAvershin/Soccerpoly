"""Enumerate the published Cup shot outcomes against a designer's cash target."""
import json

SOURCE = ["content/continental-cup.json"]
COLUMNS = "scenario,target,safe_cash,payout,weight"
OPTIONS = ["take_guarantee", "take_shot", "defer_purchase"]
QUESTION = ("Meet the cash target with the highest possible probability. Prefer the guarantee "
            "when it covers the target. If neither action can reach it, defer the purchase. "
            "probability_bp is the shot success probability in basis points.")
CONTROL = "above_best_shot"


def samples(root):
    cup = json.loads((root / SOURCE[0]).read_text())
    safe = cup["safe_cash"]
    maximum = max(shot["cash"] for shot in cup["shots"])
    for scenario, target in [("at_guarantee", safe), ("above_guarantee", safe+1),
                             ("at_best_shot", maximum), (CONTROL, maximum+1)]:
        for shot in cup["shots"]:
            yield scenario, target, safe, shot["cash"], shot["weight"]


def decision(metrics):
    if metrics["safe_cash"] >= metrics["target"]:
        return OPTIONS[0]
    return OPTIONS[1] if metrics["probability_bp"] else OPTIONS[2]
