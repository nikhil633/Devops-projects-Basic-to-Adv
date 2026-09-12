#!/usr/bin/env python3
"""
github_last_commits.py

Extract the last pushed commit (author, sha, date, message) across many
private GitHub repos in an org — a common "who touched what, and when"
audit DevOps engineers run before releases, offboarding, or access reviews.

Auth:
    export GITHUB_TOKEN="ghp_xxx"   # needs repo:read on the org

Usage:
    python github_last_commits.py --org my-org
    python github_last_commits.py --org my-org --branch main
    python github_last_commits.py --repos repo1 repo2 repo3
    python github_last_commits.py --org my-org --csv out.csv

Notes:
    - Uses the REST API directly (requests) so there's no extra SDK
      dependency to manage in CI runners.
    - Paginates through org repos automatically (GitHub caps page size at 100).
    - Handles repos with zero commits / empty default branch gracefully.
"""

import argparse
import csv
import os
import sys
import time
from typing import Iterable

import requests

API = "https://api.github.com"


def _headers(token: str) -> dict:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _get(url: str, headers: dict, params: dict | None = None) -> requests.Response:
    """GET with basic rate-limit backoff (GitHub secondary rate limits)."""
    for attempt in range(5):
        resp = requests.get(url, headers=headers, params=params, timeout=30)
        if resp.status_code == 403 and "rate limit" in resp.text.lower():
            wait = int(resp.headers.get("Retry-After", 10))
            print(f"  rate limited, sleeping {wait}s...", file=sys.stderr)
            time.sleep(wait)
            continue
        return resp
    return resp


def list_org_repos(org: str, token: str, include_forks: bool = False) -> list[dict]:
    repos, page = [], 1
    while True:
        resp = _get(
            f"{API}/orgs/{org}/repos",
            _headers(token),
            params={"per_page": 100, "page": page, "type": "private"},
        )
        resp.raise_for_status()
        batch = resp.json()
        if not batch:
            break
        repos.extend(r for r in batch if include_forks or not r.get("fork"))
        page += 1
    return repos


def last_commit(owner: str, repo: str, token: str, branch: str | None) -> dict | None:
    """Return the newest commit on `branch` (or the repo's default branch)."""
    params = {"per_page": 1}
    if branch:
        params["sha"] = branch
    resp = _get(f"{API}/repos/{owner}/{repo}/commits", _headers(token), params=params)
    if resp.status_code == 409:  # empty repo
        return None
    resp.raise_for_status()
    commits = resp.json()
    if not commits:
        return None
    c = commits[0]
    author_login = (c.get("author") or {}).get("login")
    commit_author_name = c["commit"]["author"]["name"]
    return {
        "repo": repo,
        "sha": c["sha"][:10],
        "author_login": author_login or "(no linked GitHub user)",
        "author_name": commit_author_name,
        "date": c["commit"]["author"]["date"],
        "message": c["commit"]["message"].splitlines()[0][:80],
    }


def run(owner: str, repo_names: Iterable[str], token: str, branch: str | None) -> list[dict]:
    rows = []
    for name in repo_names:
        print(f"Checking {owner}/{name}...", file=sys.stderr)
        try:
            row = last_commit(owner, name, token, branch)
        except requests.HTTPError as e:
            print(f"  skip {name}: {e}", file=sys.stderr)
            continue
        if row:
            rows.append(row)
        else:
            rows.append({"repo": name, "sha": "", "author_login": "", "author_name": "",
                         "date": "", "message": "(empty repo / branch not found)"})
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--org", help="GitHub org/owner to enumerate private repos from")
    ap.add_argument("--repos", nargs="*", help="Explicit repo names instead of --org enumeration")
    ap.add_argument("--branch", default=None, help="Branch to check (default: repo default branch)")
    ap.add_argument("--csv", default=None, help="Write results to this CSV path")
    args = ap.parse_args()

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        sys.exit("Set GITHUB_TOKEN in the environment.")
    if not args.org and not args.repos:
        sys.exit("Provide --org or --repos.")

    owner = args.org or args.repos[0].split("/")[0]
    if args.repos:
        repo_names = [r.split("/")[-1] for r in args.repos]
    else:
        repo_names = [r["name"] for r in list_org_repos(args.org, token)]
        print(f"Found {len(repo_names)} private repos in {args.org}", file=sys.stderr)

    rows = run(owner, repo_names, token, args.branch)
    rows.sort(key=lambda r: r["date"], reverse=True)

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["repo", "sha", "author_login", "author_name", "date", "message"])
            w.writeheader()
            w.writerows(rows)
        print(f"Wrote {args.csv}", file=sys.stderr)
    else:
        width = max((len(r["repo"]) for r in rows), default=10)
        for r in rows:
            print(f"{r['repo']:<{width}}  {r['date']:<20}  {r['author_login']:<20}  {r['message']}")


if __name__ == "__main__":
    main()
