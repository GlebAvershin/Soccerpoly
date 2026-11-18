"""Airflow 3 entry point for a mounted workspace, invoked manually."""
from datetime import datetime, timezone
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from airflow.sdk import dag, task


@dag(dag_id="soccerpoly_portfolio", start_date=datetime(2026, 11, 16, tzinfo=timezone.utc),
     schedule=None, catchup=False, max_active_runs=1, tags=["worlddraft", "synthetic"])
def worlddraft_pipeline():
    @task
    def rebuild():
        root = Path(os.environ["WORLDDRAFT_REPO"]).resolve()
        luau = os.environ.get("WORLDDRAFT_LUAU", "luau")
        target = Path(os.environ.get("WORLDDRAFT_ANALYTICS_OUT", str(root / "dist" / "analytics"))).resolve()
        with tempfile.TemporaryDirectory(prefix="worlddraft-airflow-") as staging:
            data = Path(staging) / "synthetic-events.jsonl"
            with data.open("w") as output:
                subprocess.run([luau, "analytics/simulate.luau"], cwd=root, stdout=output, check=True)
            subprocess.run([sys.executable, "analytics/pipeline.py", "--events", str(data),
                            "--out", str(target)], cwd=root, check=True)
        return str(target / "lineage.json")

    rebuild()


dag = worlddraft_pipeline()
