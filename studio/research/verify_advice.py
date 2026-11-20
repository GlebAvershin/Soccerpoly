"""Exercise live MCP recommendations against exhaustive one-turn outcomes."""
import asyncio
import json
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[2]


async def verify():
    cup = json.loads((ROOT/"content/continental-cup.json").read_text())
    outcomes = [shot["cash"] for shot in cup["shots"] for _ in range(shot["weight"])]
    target_max = max(cup["safe_cash"], *outcomes) + 1
    histogram = {}
    examples = {}
    params = StdioServerParameters(command=sys.executable, args=[str(ROOT/"scripts/event_context_mcp.py")])
    async with stdio_client(params) as streams, ClientSession(*streams) as session:
        await session.initialize()
        for target in range(1, target_max + 1):
            # Enumeration also handles ties. Deferring wins when both actions have zero successes.
            scores = {"defer_purchase": 0, "take_guarantee": len(outcomes)*int(cup["safe_cash"] >= target),
                      "take_shot": sum(payout >= target for payout in outcomes)}
            expected = max(scores, key=scores.get)
            reply = await session.call_tool("recommend_cup_action", {"target": target})
            data = reply.structuredContent
            if (reply.isError or not data or data["action"] != expected or data["target"] != target
                    or data["total_weight"] != len(outcomes) or data["shot_success_weight"] != scores["take_shot"]
                    or data["guaranteed_success_weight"] != scores["take_guarantee"]):
                raise ValueError(f"Recommendation failed at target {target}")
            histogram[expected] = histogram.get(expected, 0) + 1
            if target in (cup["safe_cash"], cup["safe_cash"]+1, target_max-1, target_max):
                examples[target] = data
    return dict(tested_targets=[1,target_max], passed=target_max, by_action=histogram, boundary_examples=examples)


if __name__ == "__main__":
    print(json.dumps(asyncio.run(verify()), indent=2))
