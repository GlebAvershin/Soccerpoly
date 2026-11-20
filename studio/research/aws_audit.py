"""Compare every one-turn purchase target with the shipped Event Studio advisor."""
import json
import sys

SOURCE = "content/continental-cup.json"


def load_input(root):
    cup = json.loads((root / SOURCE).read_text())
    return {"safe": cup["safe_cash"], "shots": [[s["cash"], s["weight"]] for s in cup["shots"]]}


def analyze(data):
    shots = data["shots"]
    total = sum(weight for cash, weight in shots)
    ceiling = max([data["safe"]] + [cash for cash, weight in shots])
    bands = []
    for amount in range(1, ceiling + 2):
        shot_weight = sum(weight for cash, weight in shots if cash >= amount)
        if amount <= data["safe"]:
            action, success = "take_guarantee", total
        elif shot_weight:
            action, success = "take_shot", shot_weight
        else:
            action, success = "defer_purchase", 0
        if bands and bands[-1]["action"] == action and bands[-1]["success_weight"] == success:
            bands[-1]["last"] = amount
        else:
            bands.append({"first": amount, "last": amount, "action": action, "success_weight": success})
    return {"total_weight": total, "targets_checked": ceiling + 1, "bands": bands}


def verify(root, result):
    sys.path.insert(0, str(root / "scripts"))
    from event_studio import load, recommend_cash

    cup, _ = load(root / SOURCE)
    last = 0
    for band in result["bands"]:
        assert band["first"] == last + 1
        for amount in range(band["first"], band["last"] + 1):
            advice = recommend_cash(cup, amount)
            assert (advice["action"], advice["total_weight"]) == (band["action"], result["total_weight"])
            assert max(advice["guaranteed_success_weight"], advice["shot_success_weight"]) == band["success_weight"]
        last = band["last"]
    assert last == result["targets_checked"] == max([cup["safe_cash"]] + [s["cash"] for s in cup["shots"]]) + 1
