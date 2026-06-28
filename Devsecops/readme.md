vim pre-commit.sh

#!bin/bash

echo " Running native pre-commit hook..."

if git diff --cached | grep -i "secret"; then 
  echo "Secret detected. Commit blocked"
  exit 1
fi

echo "Commit passed security checks."
exit 0
chmod +x pre-commit
delete script after that
-------------


pip install pre-commit - goto website and check
create .pre-commit-config.yaml  - vim .pre-commit-config.yaml

repos:
  - repo: https//github.com/gitleaks/gitleaks
    rev: v8.24.2
    hooks:
      - id: gitleaks

pre-commit install
gitleaks detect
pre-commit autodetect

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


pip install checkov
checkov --version

create insecure terraform directory

mkdir terraform-checkov-demo
cd terraform-checkov-demo

checkov -d .

install vault 

sudo apt update
sudo apt install -y unzip wget
wget https://releases.hashicorp.com/vault/1.15.5/vault_1.15.5_linux_amd64.zip
unzip vault_1.15.5_linux_amd64.zip
sudo mv vault /usr/local/bin/
vault version

vault server -dev -dev-root-token-id="root" -dev-listen-address="0.0.0.0:8200"

