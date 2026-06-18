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
