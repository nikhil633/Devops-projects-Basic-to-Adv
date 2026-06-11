# istio/install.sh
#
# Installs Istio in AMBIENT MODE (no sidecars).
#
# ── Sidecar vs Ambient ────────────────────────────────────────────────────
#
# Traditional Istio (sidecar mode):
#   Every pod gets an Envoy proxy injected as a sidecar container.
#   Problem: doubles memory per pod, complicates debugging, slow rollouts.
#
# Ambient mode (Istio 1.21+):
#   No sidecars. A per-node ztunnel handles L4 (mTLS, TCP routing).
#   A waypoint proxy handles L7 (HTTP routing, retries, circuit breaking)
#   only for services that need it — opt-in, not opt-out.
#   Result: 90% less memory overhead, no pod restart needed to enable mesh.
#
# This is the recommended mode for new deployments as of 2024.

set -euo pipefail

ISTIO_VERSION="1.22.0"

echo "=== Installing Istio ${ISTIO_VERSION} in Ambient mode ==="

# Download istioctl
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
export PATH="${PWD}/istio-${ISTIO_VERSION}/bin:$PATH"

# Install with ambient profile (no sidecars)
istioctl install --set profile=ambient --skip-confirmation

# Verify installation
kubectl wait --for=condition=Ready pods --all -n istio-system --timeout=120s
echo "Istio control plane ready"

# Install Kubernetes Gateway API CRDs (required for Ambient mode routing)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

echo ""
echo "=== Enabling ambient mesh for namespaces ==="
# Label namespaces to enrol in ambient mesh (no pod restart needed)
for ns in dev staging prod; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "$ns" \
    istio.io/dataplane-mode=ambient \
    --overwrite
  echo "  Namespace $ns enrolled in ambient mesh"
done

echo ""
echo "=== Installing Kiali (Istio observability dashboard) ==="
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/addons/jaeger.yaml

echo ""
echo "=== Done. Access Kiali: kubectl port-forward svc/kiali -n istio-system 20001:20001 ==="
