# DevOps Python Script Pack

Five scripts covering the checks that come up most often day to day.

| Script | Purpose |
|---|---|
| `github_last_commits.py` | Last pushed commit + author across N private repos (your original ask) |
| `github_stale_branches.py` | Branches with no commits in X days, org- or repo-wide |
| `github_open_prs_report.py` | Open PR digest: age, author, draft status |
| `k8s_pod_health_check.py` | Cluster-wide pod triage: crash loops, high restarts, bad phase |
| `terraform_drift_check.py` | `terraform plan` drift summary across multiple state dirs, CI-gatable |

## Setup

```bash
pip install requests kubernetes --break-system-packages
export GITHUB_TOKEN="ghp_xxx"     # for the github_*.py scripts
```

For `k8s_pod_health_check.py`, point kubectl/kubeconfig at your AKS cluster first:
```bash
az aks get-credentials --resource-group <rg> --name <cluster>
```

For `terraform_drift_check.py`, make sure the ambient cloud auth (Azure OIDC /
`az login`, or AWS creds) that Terraform needs is already set up in the shell —
the script doesn't manage auth itself.

## Extending to "20 private repos" specifically

`github_last_commits.py --org my-org` auto-paginates and covers as many repos
as the org has (no manual list of 20 names needed) — but if you want an
explicit subset:

```bash
python github_last_commits.py --repos repo1 repo2 repo3 ... repo20 --csv commits.csv
```

The `--csv` flag is useful here since a 20-repo run is easier to skim as a
spreadsheet than a terminal dump.
