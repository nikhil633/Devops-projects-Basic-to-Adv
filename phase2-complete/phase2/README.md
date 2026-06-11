# Phase 2 — Full DevOps Stack

## What's in this folder

```
phase2/
├── dockerfiles/
│   ├── python/Dockerfile       Multi-stage distroless — tests run inside build
│   ├── nodejs/Dockerfile       Multi-stage alpine — prod deps only at runtime
│   ├── go/Dockerfile           Multi-stage distroless/static — fully static binary
│   ├── rust/Dockerfile         cargo-chef for dep caching, debian-slim runtime
│   └── java/Dockerfile         Layered Spring Boot JAR — only app layer rebuilds
│
├── terraform/
│   ├── aws/
│   │   ├── modules/
│   │   │   ├── vpc/            VPC + 3 public + 3 private subnets + NAT GW + flow logs
│   │   │   ├── eks/            EKS cluster + node groups + IRSA + addons + KMS
│   │   │   └── ecr/            One ECR repo per service + lifecycle + scan policies
│   │   └── envs/
│   │       ├── dev/            Spot nodes, public API, small instances
│   │       └── prod/           On-Demand, private API, larger instances, VPN-only access
│   └── azure/
│       ├── modules/
│       │   ├── vnet/           VNet + AKS subnet + App Gateway subnet + NSGs
│       │   ├── aks/            AKS + Workload Identity + AGIC + Key Vault + Log Analytics
│       │   └── acr/            ACR + lifecycle + AcrPull for AKS + AcrPush for GitHub
│       └── envs/
│           ├── dev/            Spot VMs, smaller nodes, federated GitHub OIDC
│           └── prod/           On-Demand, approval gates, geo-replicated ACR
│
├── helm/
│   └── charts/
│       └── python-url-shortener/   (same structure for all 5 services)
│           ├── Chart.yaml
│           ├── values.yaml         Base defaults
│           ├── values-dev.yaml     Dev overrides (1 replica, debug logs, no PDB)
│           ├── values-prod.yaml    Prod overrides (3+ replicas, TLS, PDB, HPA)
│           └── templates/
│               ├── deployment.yaml     Rolling update, security context, probes
│               ├── service.yaml
│               ├── _helpers.tpl
│               └── ingress-hpa-pdb-sm.yaml   Ingress + HPA + PDB + ServiceMonitor
│
├── argocd/
│   ├── applicationset.yaml         Matrix generator: 5 services × 3 envs = 15 apps
│   └── image-updater-config.yaml   Auto-updates image tags from ECR/ACR
│
├── github-actions/
│   ├── python-url-shortener.yml    Full detailed pipeline for Python
│   ├── reusable-service-pipeline.yml   Reusable workflow (matrix: aws + azure)
│   └── other-services.yml          Caller workflows for Node/Go/Rust/Java
│
├── azure-devops/
│   ├── python-url-shortener.yml    Full detailed pipeline for Python
│   ├── templates/
│   │   └── service-pipeline-template.yml   Reusable template
│   ├── nodejs-notification.yml
│   ├── go-auth.yml
│   ├── rust-ratelimiter.yml
│   └── java-inventory.yml
│
└── monitoring/
    ├── prometheus/
    │   ├── kube-prometheus-stack-values.yaml   Installs Prometheus + Grafana + Alertmanager
    │   └── alert-rules.yaml    Custom PrometheusRules: error rate, latency, pod health
    └── grafana/
        ├── microservices-dashboard.yaml    4 Golden Signals for all services
        └── slo-dashboard.yaml              Error budgets + burn rate
```

---

## Deployment order

Follow this exact sequence. Each step depends on the one before.

### Step 1 — Bootstrap Terraform remote state (do once)

**AWS:**
```bash
# Create S3 bucket and DynamoDB table for state locking
aws s3api create-bucket --bucket my-project-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket my-project-terraform-state \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket my-project-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws dynamodb create-table --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

**Azure:**
```bash
# Create resource group and storage account for state
az group create --name terraform-state-rg --location eastus
az storage account create --name myprojtfstate --resource-group terraform-state-rg \
  --sku Standard_LRS --encryption-services blob
az storage container create --name tfstate \
  --account-name myprojtfstate
```

---

### Step 2 — Create GitHub OIDC provider in AWS (do once per account)

```bash
# GitHub's OIDC thumbprint
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

---

### Step 3 — Apply Terraform

```bash
# Dev environment (AWS)
cd terraform/aws/envs/dev
terraform init
terraform plan -var="github_org=your-org" -var="github_repo=your-repo"
terraform apply -var="github_org=your-org" -var="github_repo=your-repo"

# Note the outputs — you'll need cluster_name, ecr_urls, github_actions_role
terraform output

# Dev environment (Azure)
cd terraform/azure/envs/dev
terraform init
terraform plan -var="github_org=your-org" -var="github_repo=your-repo"
terraform apply -var="github_org=your-org" -var="github_repo=your-repo"

# Note acr_login_server, cluster_name, client_id, oidc_issuer_url
terraform output
```

---

### Step 4 — Configure GitHub Secrets

In your GitHub repo → Settings → Secrets and variables → Actions:

| Secret | Value | Source |
|--------|-------|--------|
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | `arn:aws:iam::...` | Terraform output: `github_actions_role` |
| `EKS_CLUSTER_NAME_DEV` | cluster name | Terraform output: `cluster_name` |
| `AZURE_CLIENT_ID` | UUID | Terraform output: `client_id` |
| `AZURE_TENANT_ID` | UUID | `az account show --query tenantId` |
| `AZURE_SUBSCRIPTION_ID` | UUID | `az account show --query id` |
| `ACR_NAME` | registry name | Terraform output: `acr_login_server` (prefix only) |
| `ACR_LOGIN_SERVER` | full URL | Terraform output: `acr_login_server` |
| `AKS_CLUSTER_NAME_DEV` | cluster name | Terraform output: `cluster_name` |
| `AKS_RESOURCE_GROUP_DEV` | RG name | Terraform output: `resource_group` |

In Variables (not Secrets):
| Variable | Value |
|----------|-------|
| `PROJECT` | `myproject` |

---

### Step 5 — Install ArgoCD

```bash
# Connect to EKS
aws eks update-kubeconfig --region us-east-1 --name <cluster_name>

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=120s

# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d

# Apply the ApplicationSet (creates all 15 applications)
kubectl apply -f argocd/applicationset.yaml

# Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 — login: admin / <password above>
```

For AKS:
```bash
az aks get-credentials --resource-group <rg> --name <cluster_name>
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/applicationset.yaml
```

---

### Step 6 — Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/prometheus/kube-prometheus-stack-values.yaml \
  --wait

# Apply custom alert rules
kubectl apply -f monitoring/prometheus/alert-rules.yaml

# Apply Grafana dashboards (picked up automatically by the sidecar)
kubectl apply -f monitoring/grafana/microservices-dashboard.yaml
kubectl apply -f monitoring/grafana/slo-dashboard.yaml

# Access Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# Open http://localhost:3000 — login: admin / changeme123
```

---

### Step 7 — Trigger your first deployment

Push any change to a Phase 1 service directory on the `main` branch.
Example:
```bash
# Touch a file to trigger the pipeline
echo "# trigger" >> python-url-shortener/README.md
git add . && git commit -m "chore: trigger first deployment"
git push origin main
```

Watch it run:
- **GitHub Actions**: repo → Actions tab → `python-url-shortener` workflow
- **ArgoCD**: https://localhost:8080 — watch the app sync from yellow → green
- **Grafana**: http://localhost:3000 → Microservices Golden Signals dashboard
- **Prometheus**: `kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090`

---

## Key concepts in this stack

**Why OIDC and no stored secrets?**
GitHub Actions and Azure DevOps both support exchanging a short-lived OIDC
token for cloud credentials at runtime. No passwords are stored in GitHub
Secrets or Azure DevOps variable groups — only role ARNs and client IDs,
which are not secret. If a token is intercepted it expires in 15 minutes.

**Why multi-stage Dockerfiles?**
Each stage has a specific job. The build stage has compilers and dev tools.
The runtime stage has only what's needed to run. Intermediate stages are
discarded. Result: small images (Go: ~10MB, Python: ~80MB) with no build
tools that an attacker could use.

**Why `--atomic` in Helm?**
`--atomic` means: if any pod fails its readiness probe during the rollout,
Helm automatically runs `helm rollback` to the previous release. You get
zero-touch rollback without writing extra pipeline steps.

**Why ArgoCD on top of Helm in CI?**
CI updates the image tag in Git. ArgoCD deploys from Git.
This means the cluster's desired state is always in Git — you can see
what's deployed by reading a file, not by running `kubectl` commands.
If the cluster is accidentally wiped, ArgoCD restores everything from Git.

**Why ServiceMonitors instead of scrape annotations?**
Annotations (`prometheus.io/scrape=true`) are static — they can't express
TLS config, custom labels, or interval overrides. ServiceMonitor CRDs give
you all of that, and they're version-controlled in the Helm chart.
