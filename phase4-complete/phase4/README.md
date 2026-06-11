# Phase 4 — Production-Grade DevOps

## What's in this folder

```
phase4/
├── istio/
│   ├── install.sh                    Installs Istio in Ambient mode (no sidecars)
│   ├── gateway/
│   │   └── gateway.yaml              Entry point + mesh-wide mTLS enforcement
│   ├── virtualservices/
│   │   └── all-services.yaml         Traffic routing, retries, timeouts per service
│   ├── destinationrules/
│   │   └── all-services.yaml         Circuit breaking, connection pools, outlier detection
│   └── authorizationpolicies/
│       └── zero-trust.yaml           Default deny-all + explicit allow per service pair
│
├── flagger/
│   └── canary-deployments.yaml       Auto canary for all 5 Phase 3 services
│
├── keda/
│   └── scaled-objects.yaml           Event-driven autoscaling (Kafka lag, queue depth, RPS)
│
├── opa-gatekeeper/
│   ├── templates/
│   │   └── constraint-templates.yaml Policy definitions in Rego
│   └── constraints/
│       └── prod-constraints.yaml     Enforce policies in prod (deny), warn in dev
│
├── opentelemetry/
│   ├── otel-collector.yaml           Collector: receives traces/metrics/logs, exports to Jaeger+Loki
│   └── instrumentation.yaml          Auto-instrument Python/Java/Node.js without code changes
│
├── falco/
│   └── falco-rules.yaml              Runtime security: shell spawns, unexpected connections, crypto miners
│
├── cosign/
│   ├── sign-and-verify.sh            Script: sign image + attach SBOM + verify
│   └── policy-controller.yaml        Admission webhook: reject unsigned images in prod
│
├── cilium/
│   └── network-policies.yaml         L7-aware pod firewall via eBPF
│
├── velero/
│   ├── backup-schedules.yaml         Daily full + hourly prod backups to S3/Azure Blob
│   └── restore-runbook.sh            Step-by-step disaster recovery procedure
│
├── dockerfiles/                      Multi-stage Dockerfiles for all Phase 3 services
│   ├── rust-realtime-chat.Dockerfile
│   ├── python-ml-inference.Dockerfile
│   ├── java-event-sourcing.Dockerfile
│   └── nodejs-bff-gateway.Dockerfile
│
└── phase3-services-pipeline.yml      GitHub Actions CI/CD with Cosign signing
```

---

## Deployment order

**Phase 4 must be deployed AFTER Phase 2** (cluster exists) and on top of the
Phase 3 application services. Follow this sequence exactly.

### Step 1 — Install Istio

```bash
chmod +x istio/install.sh
./istio/install.sh

# Verify
kubectl get pods -n istio-system
kubectl get gtw -A    # Gateway API resources
```

### Step 2 — Apply Istio traffic policies

```bash
# Gateway + mesh-wide mTLS
kubectl apply -f istio/gateway/gateway.yaml

# Traffic routing rules
kubectl apply -f istio/virtualservices/all-services.yaml

# Circuit breaking + connection pools
kubectl apply -f istio/destinationrules/all-services.yaml

# Zero-trust access control (apply LAST — will block traffic until services are up)
kubectl apply -f istio/authorizationpolicies/zero-trust.yaml
```

### Step 3 — Install Flagger (canary deployments)

```bash
helm repo add flagger https://flagger.app
helm repo update

# Install Flagger with Istio provider
helm upgrade --install flagger flagger/flagger \
  --namespace istio-system \
  --set meshProvider=istio \
  --set metricsServer=http://prometheus.monitoring:9090

# Install load tester (used by canary webhooks)
helm upgrade --install flagger-loadtester flagger/loadtester \
  --namespace test \
  --create-namespace

# Apply canary resources
kubectl apply -f flagger/canary-deployments.yaml

# Verify canaries are initialised
kubectl get canaries -n prod
```

### Step 4 — Install KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace

# Apply ScaledObjects
kubectl apply -f keda/scaled-objects.yaml

# Verify
kubectl get scaledobjects -n prod
kubectl get hpa -n prod   # KEDA creates HPAs automatically
```

### Step 5 — Install OPA Gatekeeper

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.16/deploy/gatekeeper.yaml

# Wait for gatekeeper to be ready
kubectl wait --for=condition=Ready pods --all -n gatekeeper-system --timeout=120s

# Apply ConstraintTemplates first
kubectl apply -f opa-gatekeeper/templates/constraint-templates.yaml

# Wait for CRDs to register (takes ~30s)
sleep 30

# Apply constraints (start with warn, then change to deny after testing)
kubectl apply -f opa-gatekeeper/constraints/prod-constraints.yaml

# Test a policy violation (should be rejected)
kubectl run test-root --image=nginx --overrides='{"spec":{"securityContext":{"runAsUser":0}}}' -n prod
```

### Step 6 — Install OpenTelemetry

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Install the operator
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace monitoring \
  --set "manager.collectorImage.repository=otel/opentelemetry-collector-contrib"

# Install the collector
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --values opentelemetry/otel-collector.yaml

# Apply auto-instrumentation configs
kubectl apply -f opentelemetry/instrumentation.yaml

# Restart Phase 3 pods to pick up auto-instrumentation
kubectl rollout restart deployment -n prod
```

### Step 7 — Install Falco (runtime security)

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm upgrade --install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=ebpf \
  --values falco/falco-rules.yaml

# Verify Falco is running on all nodes
kubectl get pods -n falco -o wide

# Test a rule (should trigger a Falco alert)
kubectl exec -it <any-pod> -n prod -- /bin/sh 2>/dev/null || echo "Shell blocked (distroless)"
```

### Step 8 — Install Cosign Policy Controller

```bash
helm repo add sigstore https://sigstore.github.io/helm-charts
helm repo update

helm upgrade --install policy-controller sigstore/policy-controller \
  --namespace cosign-system \
  --create-namespace

# Apply image policy (start in warn mode)
kubectl apply -f cosign/policy-controller.yaml

# Test signing manually
chmod +x cosign/sign-and-verify.sh
./cosign/sign-and-verify.sh myregistry.azurecr.io/python-ml-inference:sha-abc1234
```

### Step 9 — Install Velero (backup)

```bash
# Install Velero CLI
brew install velero   # macOS
# or: https://velero.io/docs/latest/basic-install/

# Create S3 bucket for backups (AWS)
aws s3 mb s3://my-velero-backups --region us-east-1

# Install Velero on cluster
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket my-velero-backups \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --secret-file ./credentials-velero

# Apply backup schedules
kubectl apply -f velero/backup-schedules.yaml

# Verify first backup
velero backup get
```

### Step 10 — Deploy Phase 3 services with Phase 4 pipeline

Push any Phase 3 service change to trigger the full pipeline:

```bash
echo "# trigger" >> rust-realtime-chat/README.md
git add . && git commit -m "chore: trigger phase 4 pipeline"
git push origin main
```

Watch the full flow:
- GitHub Actions: build → Trivy scan → Cosign sign → deploy
- Flagger: canary starts at 0% → increments to 100% if metrics pass
- KEDA: pods scale up as Kafka lag or queue depth grows
- Grafana: golden signals dashboard updates
- Kiali: service mesh topology map shows live traffic

---

## What each tool adds and why it matters

### Istio Ambient Mode
mTLS between every service pair — without sidecars. Zero-trust networking
where every service-to-service call is authenticated by SPIFFE X.509 certs.
The AuthorizationPolicy `deny-all` means a compromised pod cannot call any
other service by default — it must be explicitly allowed.

### Flagger Canary
Automatic progressive delivery with metric-gated promotion.
New image → 5% traffic → check error rate and P99 → 10% → check → 15% ...
If error rate exceeds 1% at any step → automatic rollback, Slack alert.
No manual rollback needed. No downtime.

### KEDA
Kafka consumer lag drives pod count.
When `account-events` topic has 1000 unconsumed messages → scale Java event
sourcing from 2 to 10 pods. When lag clears → scale back to 2 after cooldown.
HPA cannot do this (it only sees CPU/memory).

### OPA Gatekeeper
Policy as code. Every Deployment to prod must have resource limits, must not
run as root, must use immutable image tags, must have standard labels.
Violation → API server rejects the resource before it lands in the cluster.
No human review needed — the cluster enforces the policy.

### OpenTelemetry
Single trace ID connects a GraphQL query → BFF → Auth → Inventory → DB query.
Auto-instrumentation injects the SDK via init container — no code changes in
the Phase 3 services. Traces flow to Jaeger. Metrics flow to Prometheus.
Logs flow to Loki. One pane of glass in Grafana.

### Falco
Detects what Trivy and OPA miss — runtime behaviour.
Shell spawned inside a distroless container → immediate CRITICAL alert.
Unexpected outbound TCP connection → WARNING.
Crypto miner process → CRITICAL.
Runs as a DaemonSet — one Falco pod per node, using eBPF kernel hooks.

### Cosign
Every image pushed to ECR/ACR is signed with an ephemeral key tied to the
GitHub Actions OIDC token. The Policy Controller admission webhook verifies
the signature before any pod starts. An image that was not built by your
CI pipeline cannot run in prod.

### Cilium
Enforces which pods can talk to which pods at the kernel level via eBPF.
BFF can call Inventory (port 8080) but cannot call PostgreSQL (port 5432).
ML Inference can only receive traffic from BFF — nothing else.
Even if Istio AuthorizationPolicy is misconfigured, Cilium catches it.
Defence in depth.

### Velero
Daily full cluster backup + hourly prod backup to S3/Azure Blob.
If the entire cluster is deleted → `velero restore create --from-backup latest`
restores all resources and PVCs within minutes.
Tested via restore-runbook.sh.
