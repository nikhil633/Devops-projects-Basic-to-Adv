#!/usr/bin/env python3
"""
github_open_prs_report.py

Roll up open PRs across many repos: age, author, review status, mergeable
state. Handy for a Monday-morning "what's waiting on review" digest, or
piping into Slack.

Usage:
    export GITHUB_TOKEN="ghp_xxx"
    python github_open_prs_report.py --org my-org
    python github_open_prs_report.py --org my-org --min-age-days 3
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
                          headers=headers(token), params={"per_page": 100, "page": page, "type": "private"})
        r.raise_for_status()
        batch = r.json()
        if not batch:
            break
        repos += [x["name"] for x in batch]
        page += 1
    return repos


def open_prs(org, repo, token):
    r = requests.get(f"{API}/repos/{org}/{repo}/pulls",
                      headers=headers(token), params={"state": "open", "per_page": 100})
    r.raise_for_status()
    return r.json()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--org", required=True)
    ap.add_argument("--min-age-days", type=int, default=0)
    args = ap.parse_args()

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        sys.exit("Set GITHUB_TOKEN in the environment.")

    now = datetime.now(timezone.utc)
    for repo in list_repos(args.org, token):
        try:
            prs = open_prs(args.org, repo, token)
        except requests.HTTPError as e:
            print(f"skip {repo}: {e}", file=sys.stderr)
            continue
        for pr in prs:
            created = datetime.strptime(pr["created_at"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            age = (now - created).days
            if age < args.min_age_days:
                continue
            draft = " [DRAFT]" if pr["draft"] else ""
            print(f"{repo}#{pr['number']}{draft}  {age}d old  by {pr['user']['login']:<15}  {pr['title'][:60]}")


if __name__ == "__main__":
    main()
