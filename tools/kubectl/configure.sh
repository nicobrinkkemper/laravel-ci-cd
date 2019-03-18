#!/bin/bash

set -e

gcloud auth activate-service-account --key-file "${GOOGLE_APPLICATION_CREDENTIALS}"
gcloud config set project handlefy
gcloud container clusters get-credentials "$K8S_CLUSTER" --zone "$K8S_ZONE"
