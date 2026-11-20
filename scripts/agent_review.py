"""Review alternative Continental Cup offers against the actual economy contract."""
from typing import Any
from mcp.server.fastmcp import FastMCP
from event_studio import load, validate

server = FastMCP("Continental Cup offer review")
OFFERS = {"offer_65": 65, "offer_84": 84, "offer_95": 95}


@server.resource("studio://review/brief")
def brief() -> dict:
    edition, stats = load()
    return {
        "instruction": "Pick an alternative guaranteed payout between mean shot cash and mean total value. "
                       "Prefer the smallest qualifying payout to limit currency issuance.",
        "options": OFFERS,
        "facts": {"edition": edition["id"], "current_offer": edition["safe_cash"],
                  "shots": edition["shots"], **stats},
    }


@server.resource("studio://review/negative-control")
def negative_control() -> str:
    return "offer_65"


@server.tool(structured_output=True)
def verify_choice(choice: str) -> dict[str, Any]:
    edition, stats = load()
    if choice not in OFFERS:
        return {"accepted": False, "reason": "Unknown offer"}
    payout = OFFERS[choice]
    try:
        validate({**edition, "safe_cash": payout})
    except ValueError as error:
        return {"accepted": False, "reason": str(error)}
    qualifying = [v for v in OFFERS.values() if stats["shot_expected_cash"] <= v <= stats["shot_expected_value"]]
    return {"accepted": payout == min(qualifying), "payout": payout,
            "reason": "Choose the lowest economy-valid alternative", **stats}


if __name__ == "__main__":
    server.run()
