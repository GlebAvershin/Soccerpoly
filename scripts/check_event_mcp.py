# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp==1.26.0"]
# ///
from __future__ import annotations

import asyncio
import json
from pathlib import Path
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from pydantic import AnyUrl


async def main():
    server = Path(__file__).with_name("event_context_mcp.py")
    async with stdio_client(StdioServerParameters(command=sys.executable, args=[str(server)])) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = {tool.name for tool in (await session.list_tools()).tools}
            assert tools == {"event_balance", "review_event_json"}
            resource = await session.read_resource(AnyUrl("worlddraft://event/continental-cup"))
            draft = resource.contents[0].text
            response = await session.call_tool("review_event_json", {"draft": draft})
            assert not response.isError
            accepted = response.structuredContent or json.loads(response.content[0].text)
            assert accepted["valid"]
            edition = json.loads(draft)
            edition["shots"][0]["weight"] = 9
            reject = await session.call_tool("review_event_json", {"draft": json.dumps(edition)})
            assert not reject.isError
            rejected = reject.structuredContent or json.loads(reject.content[0].text)
            assert rejected["valid"] is False
            print("MCP stdio: negotiated, read catalogue, accepted canonical draft and rejected invalid odds")


if __name__ == "__main__":
    asyncio.run(main())
