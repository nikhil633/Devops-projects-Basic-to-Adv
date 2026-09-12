# Ansible Daily-Ops Playbook Pack

Five playbooks covering the checks and rollouts that come up most often
managing a fleet — the Ansible counterpart to the Python/GitHub script pack.

| Playbook | Purpose |
|---|---|
| `patch_and_reboot.yml` | Update packages fleet-wide, reboot only if the kernel actually changed, rolled out in batches |
| `service_restart_safe.yml` | Rolling restart of a service, one host at a time, gated on a health check |
| `disk_cleanup_report.yml` | Report disk usage, trim journal/old rotated logs past a retention window, flag hosts still over threshold |
| `ssh_access_rollout.yml` | Grant or revoke a user's SSH access + sudo across the fleet (onboarding/offboarding) |
| `fleet_health_report.yml` | Morning sweep: uptime, load, disk, and critical service status per host, with an aggregated "needs attention" list |

## Setup

```bash
pip install ansible --break-system-packages
```

Edit `inventory/hosts.ini` with your real hosts, or rename
`inventory/azure_rm.yml.example` → `azure_rm.yml` to pull inventory
live from Azure instead of hand-maintaining a static file (needs
`pip install ansible[azure]` and `az login`).

`ansible.cfg` already points at `./inventory/hosts.ini` and assumes
`sudo` privilege escalation — adjust `remote_user` to match your VMs.

## Running

```bash
# dry run first, always
ansible-playbook playbooks/patch_and_reboot.yml --check

# real run, limited to one group
ansible-playbook playbooks/patch_and_reboot.yml -l web

# pass variables ad hoc
ansible-playbook playbooks/service_restart_safe.yml \
    -e "service_name=nginx health_check_port=80"

ansible-playbook playbooks/ssh_access_rollout.yml \
    -e "target_user=nikhil ssh_pubkey_file=~/.ssh/id_ed25519.pub state=present"
```

## Notes

- `serial:` is used in the patching and service-restart playbooks so you
  never take out a whole tier at once — adjust the batch size/percentage
  for your fleet size.
- `fleet_health_report.yml` mirrors the intent of `k8s_pod_health_check.py`
  from the Python pack, just for VM/bare-metal fleets instead of pods —
  useful if you're running a mixed AKS + VM environment.
- All playbooks are idempotent — safe to schedule via cron or a pipeline
  and re-run without side effects on hosts that are already compliant.
