#!/usr/bin/env python3
"""
terraform_drift_check.py

Runs `terraform plan -detailed-exitcode` across one or more Terraform
working directories, parses the JSON plan output, and prints a summary
of drifted resources (add/change/destroy counts) per directory. Useful
as a scheduled CI job to catch manual console changes before they bite.

Requires: terraform >= 1.1 on PATH, working credentials for the target
cloud (this uses whatever provider auth is already configured — e.g.
`az login` / OIDC for Azure).

Usage:
    python terraform_drift_check.py --dirs infra/network infra/aks infra/dns
    python terraform_drift_check.py --dirs infra/* --fail-on-drift
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run_plan(directory: Path) -> dict:
    """Run terraform init (if needed) + plan, return summary dict."""
    subprocess.run(
        ["terraform", "init", "-input=false", "-no-color"],
        cwd=directory, check=True, capture_output=True, text=True,
    )

    plan_file = directory / ".driftcheck.tfplan"
    result = subprocess.run(
        ["terraform", "plan", "-input=false", "-no-color", "-detailed-exitcode",
         f"-out={plan_file}"],
        cwd=directory, capture_output=True, text=True,
    )
    # exit code 0 = no changes, 1 = error, 2 = changes present
    if result.returncode == 1:
        return {"dir": str(directory), "error": result.stderr.strip()}

    show = subprocess.run(
        ["terraform", "show", "-json", str(plan_file)],
        cwd=directory, capture_output=True, text=True, check=True,
    )
    plan_json = json.loads(show.stdout)
    plan_file.unlink(missing_ok=True)

    changes = plan_json.get("resource_changes", [])
    counts = {"add": 0, "change": 0, "destroy": 0}
    changed_resources = []
    for c in changes:
        actions = c["change"]["actions"]
        if actions == ["no-op"] or actions == ["read"]:
            continue
        for a in actions:
            if a in counts:
                counts[a] += 1
        changed_resources.append((c["address"], "/".join(actions)))

    return {"dir": str(directory), "counts": counts, "resources": changed_resources}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirs", nargs="+", required=True, help="Terraform working directories")
    ap.add_argument("--fail-on-drift", action="store_true",
                     help="Exit non-zero if any directory has drift (for CI gating)")
    args = ap.parse_args()

    any_drift = False
    for d in args.dirs:
        directory = Path(d)
        print(f"\n== {directory} ==")
        result = run_plan(directory)
        if "error" in result:
            print(f"  ERROR: {result['error'][:300]}")
            continue
        counts = result["counts"]
        total = sum(counts.values())
        if total == 0:
            print("  no drift")
            continue
        any_drift = True
        print(f"  add={counts['add']} change={counts['change']} destroy={counts['destroy']}")
        for addr, action in result["resources"]:
            print(f"    [{action}] {addr}")

    if args.fail_on_drift and any_drift:
        sys.exit(2)


if __name__ == "__main__":
    main()
