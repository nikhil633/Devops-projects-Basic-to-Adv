UI->
after installing argocd ->
login to argocd-server and change type: clusterIp to Nodeport

login to argocd using ipaddress and create application

CLI->
download argocd cli

use commands very simple use google

argocd login 

In multi cluster install argocd on main cluster and run kubectl get cm -n argocd

open kubectl edit argocd-cmd-params-cm -n argocd

add

data:
  server.insecure: "true"

u can check in kubectl edit deploy/argocd-server -n argocd -> this above  data will get added here search insecure

kubectl edit svc argocd-server -n argo-cd -> type- clusterIp to NodePort

kubectl edit secret argocd-initial-admin-secret -n argocd
copy password decode it echo --------- | base64 --decode

argocd UI does not support adding clusters but U can delete clusters so download argocd cli and add kubernetes multiple clusters

argocd add cluster

login argocd in cli

kubectl config get-contexts copy cluster id

argocd add cluster id --server ipaddress:port

clusters will get added check in UI

