"""Enumerate the published Cup shot outcomes against a designer's cash target."""
import json

SOURCE = ["content/continental-cup.json"]
COLUMNS = "scenario,target,safe_cash,payout,weight"
OPTIONS = ["take_guarantee", "take_shot", "defer_purchase"]
QUESTION = ("Compare guaranteed_success_weight and shot_success_weight, counts over the same total. "
            "Zero for both means defer_purchase. A positive guaranteed_success_weight is always optimal "
            "(take_guarantee). A positive shot_success_weight with zero guaranteed_success_weight means "
            "take_shot. Output the exact action ID on a single line, without an explanation.")
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
    if metrics["guaranteed_success_weight"]:
        return OPTIONS[0]
    return OPTIONS[1] if metrics["shot_success_weight"] else OPTIONS[2]
