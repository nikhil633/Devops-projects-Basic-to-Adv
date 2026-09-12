#!/usr/bin/env python3
"""
github_stale_branches.py

Flag branches that haven't had a commit in N days across one or more repos.
Common cleanup task before repo audits or org migrations.

Usage:
    export GITHUB_TOKEN="ghp_xxx"
    python github_stale_branches.py --org my-org --days 90
"""

import argparse
import os
import sys
from datetime import datetime, timezone

import requests

API = "https://api.github.com"


def headers(token):
    return {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}


def list_repos(org, token):
    repos, page = [], 1
    while True:
        r = requests.get(f"{API}/orgs/{org}/repos",
                          headers=headers(token),
                          params={"per_page": 100, "page": page, "type": "private"})
        r.raise_for_status()
        batch = r.json()
        if not batch:
            break
        repos += [x["name"] for x in batch]
        page += 1
    return repos


def stale_branches(org, repo, token, days):
    stale = []
    page = 1
    while True:
        r = requests.get(f"{API}/repos/{org}/{repo}/branches",
                          headers=headers(token), params={"per_page": 100, "page": page})
        r.raise_for_status()
        branches = r.json()
        if not branches:
            break
        for b in branches:
            commit_sha = b["commit"]["sha"]
            c = requests.get(f"{API}/repos/{org}/{repo}/commits/{commit_sha}", headers=headers(token))
            c.raise_for_status()
            date_str = c.json()["commit"]["author"]["date"]
            commit_date = datetime.strptime(date_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            age_days = (datetime.now(timezone.utc) - commit_date).days
            if age_days >= days:
                stale.append((b["name"], age_days, date_str))
        page += 1
    return stale


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--org", required=True)
    ap.add_argument("--days", type=int, default=90)
    ap.add_argument("--repos", nargs="*", help="Limit to specific repos")
    args = ap.parse_args()

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        sys.exit("Set GITHUB_TOKEN in the environment.")

    repo_names = args.repos or list_repos(args.org, token)
    for repo in repo_names:
        try:
            stale = stale_branches(args.org, repo, token, args.days)
        except requests.HTTPError as e:
            print(f"skip {repo}: {e}", file=sys.stderr)
            continue
        if stale:
            print(f"\n{repo}:")
            for name, age, date in sorted(stale, key=lambda x: -x[1]):
                print(f"  {name:<40} last commit {age}d ago ({date})")


if __name__ == "__main__":
    main()
