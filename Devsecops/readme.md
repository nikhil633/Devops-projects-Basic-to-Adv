#!bin/bash

echo " Running native pre-commit hook..."

if git diff --cached | grep -i "secret"; then 
  echo "Secret detected. Commit blocked"
  exit 1
fi

echo "Commit passed security checks."
exit 0

-------------

install pre-commit
create .pre-commit-config.yaml
pre-commit install

in CICD

name: gitleaks
on:
  pull_request:
  push:
  workflow_dispatch:
  schedule:
    - cron: "0 4 * * *" # run once a day at 4 AM
jobs:
  scan:
    name: gitleaks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v3
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }} # Only required for Organizations, not personal accounts.


hi