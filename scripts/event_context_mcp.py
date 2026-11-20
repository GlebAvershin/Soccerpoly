# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp==1.26.0"]
# ///
"""Read-only event authoring context for MCP-capable coding agents."""
from __future__ import annotations

import json

from mcp.server.fastmcp import FastMCP

from event_studio import SOURCE, load, recommend_cash, validate

server = FastMCP("Soccerpoly Event Studio")


@server.resource("worlddraft://event/continental-cup")
def event_catalog() -> str:
    """Canonical EN/RU catalog and input format for seasonal updates."""
    return SOURCE.read_text()


@server.tool()
def event_balance() -> dict:
    """Return current catalogue metrics and allowed outcomes."""
    edition, stats = load()
    return {"edition": edition["id"], "safe_cash": edition["safe_cash"], **stats}


@server.tool(structured_output=True)
def recommend_cup_action(target: int) -> dict[str, int | str]:
    """Select the Cup action most likely to cover the additional cash needed in one turn."""
    edition, _ = load()
    return recommend_cash(edition, target)


@server.tool()
def review_event_json(draft: str) -> dict:
    """Validate a proposed catalog using the same checks as CI. Does not write files."""
    if len(draft) > 16_384:
        return {"valid": False, "error": "Draft exceeds 16 Ki characters"}
    try:
        edition = json.loads(draft)
        return {"valid": True, **validate(edition)}
    except ValueError as exc:
        return {"valid": False, "error": str(exc)}


if __name__ == "__main__":
    server.run(transport="stdio")
