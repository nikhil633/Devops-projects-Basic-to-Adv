#!/bin/bash
# velero/restore-runbook.sh
# Step-by-step disaster recovery procedure.
# Run this if the prod cluster is destroyed and needs to be rebuilt.

set -euo pipefail

BACKUP_NAME="${1:-}"
NAMESPACE="${2:-prod}"

echo "=== Velero Disaster Recovery Runbook ==="
echo ""

# ── Step 1: List available backups ───────────────────────────────────────
echo "Step 1: Available backups"
velero backup get
echo ""

# If no backup name provided, use the latest successful backup
if [[ -z "$BACKUP_NAME" ]]; then
  BACKUP_NAME=$(velero backup get -o json | \
    jq -r '.items | map(select(.status.phase=="Completed")) | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
  echo "Using latest backup: $BACKUP_NAME"
fi

# ── Step 2: Describe the backup ───────────────────────────────────────────
echo "Step 2: Backup details"
velero backup describe "$BACKUP_NAME" --details
echo ""

# ── Step 3: Restore (all namespaces) ─────────────────────────────────────
echo "Step 3: Starting restore from $BACKUP_NAME"
velero restore create \
  --from-backup "$BACKUP_NAME" \
  --include-namespaces "$NAMESPACE" \
  --restore-volumes true \
  --wait

echo ""
echo "Step 4: Checking restore status"
velero restore get

echo ""
echo "Step 5: Verify pods are running"
kubectl get pods -n "$NAMESPACE"

echo ""
echo "=== Recovery complete. Verify application health ==="
echo "Run: kubectl get pods -n $NAMESPACE"
echo "Run: kubectl get ingress -n $NAMESPACE"
