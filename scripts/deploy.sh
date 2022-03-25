#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )";
[ -d "$CURR_DIR" ] || { echo "FATAL: no current dir (maybe running in zsh?)";  exit 1; }

configfile=./config_cluster.yaml
TRAEFIK_CONFIG_DIR=./config/traefik

source "$CURR_DIR/common.sh";

# Before deploying cluster, ask for traefik configurations to be applied
info_pause_exec_options "Copy Traefik configurations folder from $( echo $TRAEFIK_CONFIG_DIR) ?" "sudo cp -r $TRAEFIK_CONFIG_DIR /data/docker/kubernetes/ && sudo ls -l /data/docker/kubernetes/traefik/"

#########
# DEPLOY CLUSTER
#########

section "Create Kubernetes cluster using cluster_config.yaml"
printf "${CYA}********************${END}\n$(cat $configfile)\n${CYA}********************${END}\n"

info_pause_exec "Create a cluster" "k3d cluster create --config $configfile"

printf "${CYA}*** checking the cluster ****${END}\n"

info_and_exec "List clusters to verify its up" "k3d cluster list"
info_and_exec "Verify that kubectl is setup/working" "kubectl get nodes"



#########
# DEPLOY TRAEFIK
#########

section "Deploying Traefik"

# info_pause_exec "deploy traefik" "kubectl apply -f ./traefik/"
info_and_exec "Apply Custom Ressources Definitions:" "kubectl apply -f ./deployments/traefik/001-traefik-crd.yaml"
info_and_exec "Apply RBAC:" "kubectl apply -f ./deployments/traefik/001-traefik-rbac.yaml"
info_and_exec "Apply Secrets:" "kubectl apply -f ./secrets/traefik/002-traefik-cloudflare-secrets.yaml"
info_and_exec "Apply Service:" "kubectl apply -f ./deployments/traefik/003-traefik-service.yaml"
info_and_exec "Apply ServiceAccount & Deployment:" "kubectl apply -f ./deployments/traefik/004-traefik-deployment.yaml"
info_and_exec "Waiting 10sec for resources to deploy correctly.." "sleep 10"
printf "\n\n$(kubectl get pods -n kube-system)\n\n"
info_and_exec "Apply ingressroute for Traefik Dashboard:" "kubectl apply -f ./deployments/traefik/005-traefik-dashboard-ingressroute.yaml"

printf "\n Traefik is deployed.\n"

############
# DEPLOY PROMETHEUS & GRAFANA
############

section "Deploying Prometheus & Grafana"
exe "kubens default"
info_and_exec "Creating a monitoring namespace for prometheus:" "kubectl create namespace monitoring"
exe "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
exe "helm repo update"
info_and_exec "Install kube-prometheus-stack helm chart:" "helm install prometheus --namespace monitoring -f ./helm/prometheus/kube-prometheus-stack-values.yaml prometheus-community/kube-prometheus-stack"
printf "Checking the pods.. \n\n $(kubectl get pods -n monitoring)\n\n"
info_and_exec "exposing prometheus via ingressroute" "kubectl apply -f ./helm/prometheus/grafana-ingressroute.yaml"


############
# DEPLOY POSTGRESQL
############

section "Deploying PostgreSQL"
info_and_exec "Create a db namespace:" "kubectl create namespace db"
exe "helm repo add bitnami https://charts.bitnami.com/bitnami"
exe "helm repo update"
info_and_exec "Install Bitnami Helm chart" "helm install pgsql --namespace db -f ./helm/postgresql/bitnami-postgresql-values.yaml bitnami/postgresql"
printf "Checking the pods.. \n\n $(kubectl get pods -n db)\n\n"
