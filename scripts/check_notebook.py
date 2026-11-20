# /// script
# requires-python = ">=3.11"
# dependencies = ["nbclient==0.10.2", "ipykernel==6.30.1"]
# ///
from pathlib import Path

import nbformat
from nbclient import NotebookClient

root = Path(__file__).resolve().parents[1]
path = root / "analytics/continental-cup.ipynb"
notebook = nbformat.read(path, as_version=4)
NotebookClient(notebook, timeout=30, resources={"metadata": {"path": str(root)}}).execute()
destination = root / "dist/analytics/continental-cup-executed.ipynb"
nbformat.write(notebook, destination)
print(f"Executed {sum(c['cell_type'] == 'code' for c in notebook.cells)} notebook cells: {destination}")
