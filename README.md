# laravel-ci-cd

## In this repo

-   Laravel
-   k8s/docker/travis config generated by [Arc](https://github.com/richdynamix/arc)
-   HTTPS generation with GKE Managed Certs
-   K8S Cluster deployment with Google Deployment Manager

# Local environment setup

> Create a secret `.env` file inside `.secrets` folder. The folder is listed in `.dockerignore` and `.gitignore`.
The following variables are going to be defined bit by bit. In the end, we will have a command-line only CI/CD setup that is triggered by pull requests. Let's look at all the variables that will end up in `.secrets/.env`.

Variable | Description | Expected values | Default
--- | --- | --- | ----
$APP_INSTANCE_NAME | The name of your app. Keep it short and don't include your project name | string/null | null
$DOMAIN | A domain which you own e.g. gabr.app  | string/null | null
$SUB_DOMAIN | A subdomain for the app e.g. api | string/null | null
$PROJECT_NAME | The project-name on Google Cloud e.g. gabr | string/null | null
$NUM_NODES | Amount of nodes of which you need 3 or more for this project | int/null | null
$NAMESPACE | The namespace | string/null | null
$TAG | The current docker tag e.g. latest or v1.0.0 | string/null | null
$DOCKER_BOT | A key for our pull and push bot e.g. docker-bot | string/null | null
$K8S_BOT | A key for our pull and push bot e.g. k8s-bot | string/null | null
$GITHUB_TOKEN | Personal Access Token used to access a private repository | string/null | null
$DOCKER_PASSWORD | Docker (service-)account password to push and pull your image | string | null
$DOCKER_REPO | The name of your Docker repository to be pushed to | string | null
$DOCKER_USERNAME | The username of your Docker (service-)account to push and pull images | string  | null
$K8S_CLUSTER | The name of the cluster in your Kubectl configuration | string | null
$K8S_ZONE | The compute zone e.g. europe-west4-a for Netherlands | string/null | null
$K8S_CLUSTER_API | Kubernetes API endpoint URL | FQDN string | null
$K8S_PASSWORD | The password of the Kubernetes service-account/user to access the cluster | string | null
$K8S_USERNAME | The username of the Kubernetes service-account/user to access the cluster | string | null
```shell
$ cat > $PWD/.secrets/.env <<- EOM
# Kubernetes app name
APP_INSTANCE_NAME=laravel
DOMAIN=example.com
SUB_DOMAIN=api
REGION=europe
PROJECT_NAME=your-google-project
NAMESPACE=default
# CI/CD
DOCKER_USERNAME=nicobrinkkemper
DOCKER_REPO=your-repo
TAG=latest
GITHUB_TOKEN=your-token
DOCKER_BOT=docker-bot
K8s_BOT=k8s-bot
K8s_NUM_NODES=3
K8S_CLUSTER=laravel-cluster
K8S_ZONE=europe-west4-a
K8S_CLUSTER_API=https://example.com/swaggerapi/
K8S_PASSWORD=$(pwgen 16 1 | tr -d '\n' | base64)
K8S_USERNAME=k8s-bot
EOM
```
> Fill in this `.env` file then use it for the active bash session

```
$ export $(grep -v '^#' ./.secrets/.env | xargs -d '\n')
```
```
gcloud container clusters get-credentials terraform-gke-cluster --zone europe-west4-a
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
# Check if tiller is running(kube-system being our default namespace)
kubectl get pods -n kube-system
```

> Create two service-accounts
```
$ gcloud auth application-default login --no-launch-browser


$ gcloud iam service-accounts create ${DOCKER_BOT} --display-name ${DOCKER_BOT}-for-ci-cd
$ gcloud iam service-accounts list
```

> Put the keys in `.secrets`
```shell
$ gcloud iam service-accounts keys create --iam-account ${DOCKER_BOT}@${PROJECT_NAME}.iam.gserviceaccount.com .secrets/${DOCKER_BOT}.gserviceaccount.json
```
> Provide it with the appropriate rights
```
gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member serviceAccount:${DOCKER_BOT}@${PROJECT_NAME}.iam.gserviceaccount.com --role roles/storage.admin


gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member serviceAccount:${DOCKER_BOT}@${PROJECT_NAME}.iam.gserviceaccount.com --role roles/viewer

```

## Deploy K8S cluster to GKE

```shell
$ gcloud auth configure-docker
```

```shell
$ gcloud config set project ${PROJECT_NAME}
```

> Get credentials for cluster. See [CLUSTER.md](/cluster.md) for two ways to create a cluster.

```
$ gcloud container clusters get-credentials $K8S_CLUSTER --zone $K8S_ZONE
```

## configure K8S Ingress to custom domain with HTTPS
[GKE-managed-certs](https://github.com/GoogleCloudPlatform/gke-managed-certs) can automatically generate `letsencrypt` certificates and renew them every three months. It only works on Google Kubernetes engine and it assumes you have DNS records setup and Google has verified your ownership over the domain. For this we will first change the generated external IP from ephemeral to static

> Setup `gcloud` as shown above, then elevate core account

```shell
$ kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user=$(gcloud config get-value core/account);
```

> Create a static ip
```shell
gcloud compute addresses create ${APP_INSTANCE_NAME}-ip --global
```

> Get static IP
```shell
gcloud compute addresses describe ${APP_INSTANCE_NAME}-ip --global --format 'value(address)'
```

> Visit your domain provider account and edit your domain settings. E.g. create A-records with names **@**, **api** and **www**, with the static IP address set as data. Providers may not automatically append your domain. If so then you must enter names as api.example.com, www.example.com, etc. Follow instructions given by your domain provider.

> Find Ingress pod
```shell
$ export INGRESS_POD=$(kubectl get pod -l app=ingress -o jsonpath="{.items[0].metadata.name}")
```

> Verify it's there
```shell
$ echo $INGRESS_POD
```

> Annotate Ingress with static ip
```shell
$ kubectl annotate ingress -n ${NAMESPACE} ${INGRESS_POD} kubernetes.io/ingress.global-static-ip-name=${APP_INSTANCE_NAME}-ip
```


Now the Ingress is using a static IP instead of a ephemeral IP. We can start setting up HTTPS as soon as the domain is pointing to your Ingress correctly.

> Create dir for deployment
```shell
$ mkdir deploy
```

> Download `managedcertificates-crd.yaml`

```shell
$ curl -sSL "https://raw.githubusercontent.com/GoogleCloudPlatform/gke-managed-certs/master/deploy/managedcertificates-crd.yaml" | \
    cat > $PWD/deploy/managedcertificates-crd.yaml -
```

> Download `managed-certificate-controller.yaml` and substitute namespace
```shell
$ curl -sSL "https://raw.githubusercontent.com/GoogleCloudPlatform/gke-managed-certs/master/deploy/managed-certificate-controller.yaml" | \
    sed -e "s/namespace: default/namespace: $NAMESPACE/g" |
    cat > $PWD/deploy/managed-certificate-controller.yaml -
```

> Apply managed certs card

```shell
$ kubectl create -f deploy/managedcertificates-crd.yaml
```

> Apply managed certs controller
```shell
$ kubectl create -f deploy/managed-certificate-controller.yaml
```

> Create file containing the certificates

```shell
$ cat > deploy/${DOMAIN}.yaml <<- EOM
apiVersion: networking.gke.io/v1beta1
kind: ManagedCertificate
metadata:
  name: ${APP_INSTANCE_NAME}-tls
  namespace: ${NAMESPACE}
spec:
  domains:
    - ${DOMAIN}
---
apiVersion: networking.gke.io/v1beta1
kind: ManagedCertificate
metadata:
  name: ${SUB_DOMAIN}-${APP_INSTANCE_NAME}-tls
  namespace: ${NAMESPACE}
spec:
  domains:
    - ${SUB_DOMAIN}.${DOMAIN}
---
apiVersion: networking.gke.io/v1beta1
kind: ManagedCertificate
metadata:
  name: www-${APP_INSTANCE_NAME}-tls
  namespace: ${NAMESPACE}
spec:
  domains:
    - www.${DOMAIN}
EOM
```

> Apply domain certificates

```shell
$ kubectl apply -n ${NAMESPACE} -f ./deploy/${DOMAIN}.yaml
```

> Find the Ingress pod

```shell
$ export INGRESS_POD=$(kubectl get pod -l app=ingress -o jsonpath="{.items[0].metadata.name}")
```
> Verify it's there
```shell
$ echo $INGRESS_POD
```

> Annotate Ingress

```shell
$ kubectl annotate ingress -n ${NAMESPACE} ${INGRESS_POD} networking.gke.io/managed-certificates=${APP_INSTANCE_NAME}-tls,www-${APP_INSTANCE_NAME}-tls,${SUB_DOMAIN}-${APP_INSTANCE_NAME} --overwrite=true
```

Your certificates will be there shortly.

## Debug `GKE-managed-certs`
Sometimes, for example when the account is not elevated, GKE-managed-certs will not generate any certificate.

> Find `managed-certificate-controller`
```shell
$ export CERT_POD=$(kubectl get pod -l app=managed-certificate-controller -o jsonpath="{.items[0].metadata.name}")
```

> Check
```shell
$ echo $CERT_POD
```

> Check logs
```shell
$ kubectl exec -it -n $NAMESPACE $CERT_POD -- cat /var/log/managed_certificate_controller.log
```
