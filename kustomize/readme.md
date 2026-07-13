apiVersion: kustomize.config.k8s.io/v1beta1
kind: kustomization

resources:
--------------provide_path here-------
- github.com/amazon/products
- ../../base

nameprefix: dev-

kubectl kustomize base  -> base is folder

