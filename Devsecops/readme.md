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

we cannot create scripts for all secrets tokens etc., so we install pre-commit
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




pip install git-filter-repo
git filter-repo --replace-text passwords.txt
git push origin --force --all


CODEOWNERS file 
DEPENDABOT

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



gcloud compute instances create devops-vm --zone=us-central1-a --machine-type=e2-medium --image-family=ubuntu-2404-lts-amd64 --image-project=ubuntu-os-cloud

gcloud init
gcloud auth list
gcloud --version


gcloud compute ssh devops-vm --zone=us-central1-a
gcloud compute instances stop devops-vm --zone=us-central1-a
gcloud compute instances start devops-vm --zone=us-central1-a
gcloud compute instances delete devops-vm --zone=us-central1-a

gcloud compute ssh vault --zone=us-central1-a
gcloud compute instances stop vault --zone=us-central1-a
gcloud compute instances start vault --zone=us-central1-a
gcloud compute instances delete vault --zone=us-central1-a

gcloud compute ssh k8s-dev-vm --zone=us-central1-a
gcloud compute instances delete k8s-dev-vm --zone=us-central1-a
gcloud compute instances create k8s-dev-vm --zone=us-central1-a --machine-type=e2-standard-4 --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud --boot-disk-size=50GB --enable-nested-virtualization

gcloud container clusters create my-gke-cluster --zone=us-central1-a --machine-type=e2-medium --num-nodes=1
gcloud container clusters get-credentials my-gke-cluster --zone=us-central1-a


sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | \
sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
kubectl version --client
sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
gke-gcloud-auth-plugin --version


gke-gcloud-auth-plugin --version
gcloud container node-pools list --cluster=my-gke-cluster --zone=us-central1-a
gcloud container clusters resize my-gke-cluster --node-pool=default-pool --num-nodes=3 --zone=us-central1-a

disk increase for vm 

gcloud compute instances describe devops-vm --zone=us-central1-a --format="value(disks[0].source)"

gcloud compute disks resize devops-vm --size=20GB --zone=us-central1-a


gcloud container clusters list

gcloud container clusters resize my-gke-cluster --node-pool=default-pool --num-nodes=0 --zone=us-central1-a
gcloud container clusters resize my-gke-cluster --node-pool=default-pool --num-nodes=1 --zone=us-central1-a

to delete
gcloud container clusters delete my-gke-cluster --zone=us-central1-a
gcloud container clusters describe my-gke-cluster--region us-central1-a --format="yaml(meshConfig, workloadIdentityConfig, oidcConfig)"

gcloud container clusters update my-gke-cluster --zone us-central1-a --enable-oidc-issuer
gcloud container clusters describe my-gke-cluster `
    --zone us-central1-a `
    --format="yaml(workloadIdentityConfig.workloadPool, oidcConfig.issuerUri)"

gcloud container clusters describe my-gke-cluster `
>>     --zone us-central1-a `
>>     --format="value(oidcConfig.issuerUri)"  



C:\Users\reddy\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin


gcloud container clusters update my-gke-cluster --location=us-central1-a --enable-oidc-issuer

gcloud container clusters update my-gke-cluster --location=us-central1-a --workload-pool=project-3c4def04-104d-4fe8-a95.svc.id.goog

gcloud container clusters describe my-gke-cluster --location=us-central1-a --format="value(workloadIdentityConfig.workloadPool)"




kubectl port-forward service/prometheus-operated -n monitoring 9090:9090
gcloud compute ssh devops-vm --zone=us-central1-a "--" -L 9090:localhost:9090

kubectl port-forward service/monitoring-grafana -n monitoring 8080:80
gcloud compute ssh devops-vm --zone=us-central1-a "--" -L 8080:localhost:8080

kubectl port-forward service/alertmanager-operated -n monitoring 9093:9093
gcloud compute ssh devops-vm --zone=us-central1-a "--" -L 9093:localhost:9093

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-stack-ingress
  namespace: monitoring
  annotations:
    spec.ingressClassName: "gce"
spec:
  rules:
  - http:
      paths:
      # Grafana Access
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
      # Prometheus Access
      - path: /prometheus
        pathType: ImplementationSpecific
        backend:
          service:
            name: monitoring-kube-prometheus-prometheus
            port:
              number: 9090
      # Alertmanager Access
      - path: /alertmanager
        pathType: ImplementationSpecific
        backend:
          service:
            name: monitoring-kube-prometheus-alertmanager
            port:
              number: 9093



helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring --reuse-values --set prometheus.prometheusSpec.routePrefix="/" --set prometheus.prometheusSpec.externalUrl="http://34.107.177.70/prometheus" --set alertmanager.alertmanagerSpec.routePrefix="/" --set alertmanager.alertmanagerSpec.externalUrl="http://34.107.177.70/alertmanager"






