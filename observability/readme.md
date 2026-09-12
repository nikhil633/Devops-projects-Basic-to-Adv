eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster observability \
    --approve



Install all using helm or any

login to node and check with ip of prometheus-node-exporter and port number U get metrics
ex:- curl 10.100.154.178:9100/metrics

U can check even kube-state-metrics same method ip:port

expose prometheus or use ingress 
run command kube_pod_container_status_restarts_total

kubectl run busybox-crash --image=busybox -- /bin/bash -c "exit 1"

Go to Grafana ->
username: admin
password: prom-operator


Metrics types ->

1.Counter -> always incrementing ex - http requests received by app
2. Gauge -> incrementing and decrementing ex:- CPU utilization, Memory utilization or number  of config maps
3. histogram -> bucket of information ex:- http latency, 
4. Summary -> 

EFK stack Elasticsearch,FluentBit, Kibana


Install nginx ingress controller 
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

kubectl get svc -n ingress-nginx




az aks create --resource-group AKS --name myaks --node-count 1 --node-vm-size Standard_D2pls_v6 --tier free --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys



az aks create --resource-group AKS --name myaks --node-count 1 --node-vm-size Standard_D2pls_v6 --tier free --generate-ssh-keys

az aks update --resource-group AKS --name myaks --enable-oidc-issuer --enable-workload-identity

az aks show --resource-group AKS --name myaks --query "oidcIssuerProfile.issuerUrl" -o tsv

az aks show --resource-group AKS --name myaks --query "securityProfile.workloadIdentity.enabled" -o tsv



az aks get-credentials --resource-group AKS --name myaks

az aks stop --resource-group AKS --name myaks

az aks start --resource-group AKS --name myaks

az aks show --resource-group AKS --name myaks --query powerState.code

az aks delete --resource-group AKS --name myaks --yes --no-wait


ls ~/.ssh 
ls -la ~/.ssh


Install Helm 

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create ns monitoring
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring -f ./custom_kube_promtheus_stack.yml

kubectl get pods -n monitoring

kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
kubectl port-forward service/prometheus-operated -n monitoring 9090:9090
kubectl port-forward service/alertmanager-operated -n monitoring 9093:9093
kubectl port-forward service/monitoring-grafana -n monitoring 8080:80
helm uninstall monitoring --namespace monitoring
kubectl delete ns monitoring

login 
username: admin
password: prom-operator

Enable OIDC to existing AKS
az aks update --resource-group my-rg --name my-aks --enable-oidc-issuer
Enable Worload Identity
az aks update --resource-group my-rg --name my-aks --enable-workload-identity

az aks show --name my-aks --resource-group my-rg --query "oidcIssuerProfile.issuerUrl" -o tsv



eksctl create cluster \
  --name myeks \
  --region ap-south-1 \
  --nodegroup-name workers \
  --node-type t3.small \
  --nodes 1


aws eks update-kubeconfig \
  --region ap-south-1 \
  --name myeks


aws eks update-nodegroup-config \
  --cluster-name myeks \
  --nodegroup-name workers \
  --scaling-config minSize=0,maxSize=1,desiredSize=0

aws eks update-nodegroup-config \
  --cluster-name myeks \
  --nodegroup-name workers \
  --scaling-config minSize=1,maxSize=1,desiredSize=1

eksctl delete cluster \
  --name myeks \
  --region ap-south-1



sudo apt update
sudo apt install nginx -y
sudo systemctl status nginx

In Inound rules allow http -> anywhere ipv4 -> 80
                      https -> anywhere ipv4 -> 443

By default nginx create default folder 

cd /etc/nginx
ls
cd sites-available/
ls
sudo vim default
cd /var/www/html


Counter , Guage , Histogram , Summary

-----------------------------------------------------------------------------------------------

Human joining company -> Employee -> IAM Identity Center/ federated Identity -> AWS permissions -> AWS Resources 

