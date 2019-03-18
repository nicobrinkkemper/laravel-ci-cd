#!/bin/bash

set -e

gcloud auth configure-docker
gcloud config set project handlefy
gcloud container clusters get-credentials $K8S_CLUSTER --zone $K8S_ZONE

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user=$(gcloud config get-value core/account);