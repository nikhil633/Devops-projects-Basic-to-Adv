#!/bin/bash
# cosign/sign-and-verify.sh
#
# Cosign = cryptographic signing of container images.
# Proves that the image was built by YOUR CI pipeline — not tampered with.
#
# ── Supply chain attack problem ───────────────────────────────────────────
# Without signing:
#   Registry: image sha256:abc123
#   Attacker replaces it with a malicious image → same tag, different content
#   Cluster pulls the compromised image with no way to detect it.
#
# With Cosign keyless signing (Sigstore):
#   CI signs the image with an OIDC-bound ephemeral key.
#   The signature is stored in the registry alongside the image.
#   Admission webhook (Policy Controller) verifies signature before pod start.
#   Unsigned or tampered images are REJECTED by the cluster.
#
# Install: brew install cosign
# Policy Controller: helm install policy-controller sigstore/policy-controller

set -euo pipefail

IMAGE_REF="${1:?Usage: $0 <image:tag>}"
REGISTRY="${IMAGE_REF%%/*}"

echo "=== Cosign keyless signing for ${IMAGE_REF} ==="
echo ""

# ── Step 1: Sign the image (keyless — uses GitHub Actions OIDC) ──────────
# In CI, the OIDC token proves the image was built by your GitHub Actions
# workflow. The signature is stored in the registry as an OCI artifact.
cosign sign \
  --yes \
  "${IMAGE_REF}"

echo "Image signed successfully"

# ── Step 2: Verify the signature ─────────────────────────────────────────
# Verification checks:
#   - Signature exists and is cryptographically valid
#   - cert-identity matches your GitHub Actions workflow
#   - cert-oidc-issuer is GitHub's OIDC issuer (not an attacker's)
cosign verify \
  --certificate-identity-regexp "https://github.com/your-org/your-repo" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${IMAGE_REF}" | jq .

echo "Signature verified"

# ── Step 3: Generate and attach SBOM ─────────────────────────────────────
# SBOM = Software Bill of Materials — lists every package in the image.
# Required for compliance (SLSA Level 3, FedRAMP, SOC2).
# Trivy generates it, Cosign attaches it to the registry.
echo ""
echo "=== Generating SBOM ==="
trivy image \
  --format cyclonedx \
  --output sbom.json \
  "${IMAGE_REF}"

cosign attach sbom \
  --sbom sbom.json \
  "${IMAGE_REF}"

echo "SBOM attached"

# ── Step 4: Sign the SBOM ─────────────────────────────────────────────────
cosign sign \
  --yes \
  --attachment sbom \
  "${IMAGE_REF}"

echo ""
echo "=== Complete supply chain attestation for ${IMAGE_REF} ==="
echo "  ✓ Image signed"
echo "  ✓ Signature verified"
echo "  ✓ SBOM generated (CycloneDX format)"
echo "  ✓ SBOM signed and attached"
