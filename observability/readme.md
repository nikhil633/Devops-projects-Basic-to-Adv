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




az aks create --resource-group EKS --name myaks --node-count 1 --node-vm-size Standard_D2pls_v6 --tier free 

--generate-ssh-keys

az aks get-credentials --resource-group EKS --name myaks

az aks stop --resource-group EKS --name myaks

az aks start --resource-group EKS --name myaks

az aks show --resource-group EKS --name myaks --query powerState.code

az aks delete --resource-group EKS --name myaks --yes --no-wait


ls ~/.ssh 
ls -la ~/.ssh



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

