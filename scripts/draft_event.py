"""Generate a reviewable draft through an existing Bedrock or Databricks endpoint."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from event_studio import SOURCE, validate


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def model_text(provider, model, prompt):
    if provider == "bedrock":
        import boto3
        from botocore.config import Config
        response = boto3.client("bedrock-runtime", config=Config(connect_timeout=8, read_timeout=60,
                                                                  retries={"total_max_attempts": 2})).converse(
            modelId=model, messages=[{"role": "user", "content": [{"text": prompt}]}],
            inferenceConfig={"maxTokens": 8000, "temperature": 0.2})
        return "".join(block["text"] for block in response["output"]["message"]["content"] if "text" in block)
    if provider == "databricks":
        host = urlsplit(os.environ["DATABRICKS_HOST"].rstrip("/"))
        domains = (".cloud.databricks.com", ".azuredatabricks.net", ".gcp.databricks.com")
        if (host.scheme != "https" or not host.hostname or not host.hostname.endswith(domains)
                or host.username or host.password or host.port or host.path or host.query or host.fragment):
            raise ValueError("DATABRICKS_HOST must be the HTTPS workspace origin")
        url = f"https://{host.hostname}/serving-endpoints/{quote(model, safe='')}/invocations"
        request = Request(url, method="POST", headers={"Content-Type": "application/json",
                            "Authorization": f"Bearer {os.environ['DATABRICKS_TOKEN']}"},
                          data=json.dumps({"messages": [{"role": "user", "content": prompt}], "max_tokens": 8000}).encode())
        with build_opener(NoRedirect).open(request, timeout=60) as response:
            payload = json.loads(response.read(524_288))
        return payload["choices"][0]["message"]["content"]
    raise ValueError("Unsupported provider")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", choices=("bedrock", "databricks"))
    parser.add_argument("--model")
    parser.add_argument("--brief", type=Path)
    parser.add_argument("--from-response", type=Path, help="Validate a saved Codex or model reply locally")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve() == SOURCE.resolve():
        parser.error("Save a separate draft and review its diff before promotion")
    if args.from_response:
        if args.provider or args.model or args.brief:
            parser.error("Choose either a saved response or an endpoint")
        response = args.from_response.read_text()
    else:
        if not args.provider or not args.model or not args.brief:
            parser.error("Endpoint mode requires --provider, --model, and --brief")
        template = subprocess.check_output([sys.executable, str(Path(__file__).with_name("event_studio.py")), "prompt"], text=True)
        brief = args.brief.read_text()
        if not 1 <= len(brief.strip()) <= 2500:
            parser.error("Supply a short event brief of at most 2500 characters")
        response = model_text(args.provider, args.model, template + "\nDesign brief:\n" + brief)
    edition = json.loads(response)
    stats = validate(edition)
    with args.output.open("x") as stream:
        json.dump(edition, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps({"draft": str(args.output), **stats}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, ImportError) as error:
        # Provider error text can include deployment details. Output only its type.
        sys.exit(f"Draft failed: {type(error).__name__}. Check catalog syntax, provider configuration and output path.")
