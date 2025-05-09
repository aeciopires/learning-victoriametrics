#!/bin/bash
# if use Ubuntu

#!/opt/homebrew/bin/bash
# if use MacOS with brew

#------------------------
# Variables
CLUSTER_NAME="kind-multinodes"
KIND_CLUSTER_FILE="/tmp/kind-cluster.yaml"
METALLB_CHART_VERSION="0.14.9"
METALLB_FILE="/tmp/metallb-ingress-address.yaml"
CERT_MANAGER_CLUSTER_ISSUE_FILE="/tmp/cert-cluster-issue.yaml"
ARGOCD_CHART_VERSION="8.0.0"
ARGOCD_USER="admin"
ARGOCD_INITIAL_PASS="changeme"
ARGOCD_DNS="argocd.mycompany.com"
KUBE_PROMETHEUS_STACK_VERSION="v0.82.0"
KUBE_PIRES_DNS="kube-pires.mycompany.com"
#------------------------



#---------------------------------------
# Creating kind Kubernetes cluster
#---------------------------------------

if [ ! -f "$KIND_CLUSTER_FILE" ]; then

  cat << EOF > "$KIND_CLUSTER_FILE"
# References:
# Kind release image: https://github.com/kubernetes-sigs/kind/releases
# Configuration: https://kind.sigs.k8s.io/docs/user/configuration/
# Metal LB in Kind: https://kind.sigs.k8s.io/docs/user/loadbalancer
# Ingress in Kind: https://kind.sigs.k8s.io/docs/user/ingress

# Config compatible with kind v0.27.0
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
  - role: control-plane
    image: kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "nodeapp=loadbalancer"
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      listenAddress: "0.0.0.0" # Optional, defaults to "0.0.0.0"
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      listenAddress: "0.0.0.0" # Optional, defaults to "0.0.0.0"
      protocol: TCP
  - role: worker
    image: kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f
  - role: worker
    image: kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f
EOF

else
  echo "[WARNING] $KIND_CLUSTER_FILE file already exists"
fi


if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "[WARNING] Kind cluster already exists"
else
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CLUSTER_FILE"
fi
#-----------------------------------------------




#---------------------------------------
# Install MetalLB without ArgoCD
#---------------------------------------

if helm status metallb -n metallb-system >/dev/null 2>&1; then
  echo "[WARNING] Helm release metallb exists in namespace metallb-system."
else
  # Actually apply the changes, returns nonzero returncode on errors only
  kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed -e "s/strictARP: false/strictARP: true/" | \
  kubectl apply -f - -n kube-system

  # Install and upgrade Helm repositories
  helm repo add metallb https://metallb.github.io/metallb
  helm repo update

  # Install MetalLB and check if it is installed
  helm upgrade --install metallb metallb/metallb \
    --version "$METALLB_CHART_VERSION" \
    --namespace metallb-system \
    --create-namespace \
    --debug=true \
    --wait \
    --timeout=900s \
    --set "controller.tolerations[0].key=node-role.kubernetes.io/master" \
    --set "controller.tolerations[0].effect=NoSchedule" \
    --set speaker.tolerateMaster=true
fi

if [ ! -f "$METALLB_FILE" ]; then

  # Get default gateway interface
  KIND_ADDRESS=$(docker network inspect kind | jq '.[].IPAM | .Config | .[0].Subnet' | cut -d \" -f 2 | cut -d"." -f1-3)

  # Radomize Loadbalancer IP Range
  #KIND_ADDRESS_END=$(shuf -i 100-150 -n1)
  KIND_ADDRESS_END="100"
  NETWORK_SUBMASK="27"

  # Create address range
  KIND_LB_RANGE="$(echo $KIND_ADDRESS.$KIND_ADDRESS_END)/$NETWORK_SUBMASK"

  cat << EOF > "$METALLB_FILE"
# References:
# https://metallb.universe.tf/configuration/#layer-2-configuration

apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
spec:
  addresses:
  - $KIND_LB_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
spec:
  ipAddressPools:
  - first-pool
EOF
else
  echo "[WARNING] $METALLB_FILE file already exists"
fi

# Configuring CRDs of Metallb
kubectl apply -f "$METALLB_FILE" --namespace metallb-system
#-----------------------------------------------


#---------------------------------------
# Install ArgoCD
#---------------------------------------

if helm status argocd -n argocd >/dev/null 2>&1; then
  echo "[WARNING] Helm release argocd exists in namespace argocd."
else
  helm repo add argo https://argoproj.github.io/argo-helm

  helm repo update

  helm upgrade --install argocd argo/argo-cd \
    --version "$ARGOCD_CHART_VERSION" \
    --namespace argocd \
    --create-namespace \
    --debug=true \
    --wait \
    --timeout=900s \
    -f helm-apps/argocd/values.yaml

  # Configure ArgoCD
  # Change initial password
  INITIAL_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  argocd login --username $ARGOCD_USER --port-forward --port-forward-namespace argocd --insecure --password "$INITIAL_PASS"
  argocd account update-password --current-password "$INITIAL_PASS" --new-password "$ARGOCD_INITIAL_PASS" --port-forward --port-forward-namespace argocd
  kubectl -n argocd delete secret argocd-initial-admin-secret
  argocd repo add https://github.com/aeciopires/learning-victoriametrics --port-forward --port-forward-namespace argocd
fi
#-----------------------------------------------



#---------------------------------------
# Install/Sync other apps using ArgoCD
#---------------------------------------

# ingress-nginx
kubectl -n argocd apply -f helm-apps/ingress-nginx/application.yaml

# certificate-manager
kubectl -n argocd apply -f helm-apps/certificate-manager/application.yaml
# Creating a ClusterIssuer
if [ ! -f "$CERT_MANAGER_CLUSTER_ISSUE_FILE" ]; then

  cat << EOF > "$CERT_MANAGER_CLUSTER_ISSUE_FILE"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-http01
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: group@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-http01
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
else
  echo "[WARNING] $CERT_MANAGER_CLUSTER_ISSUE_FILE file already exists"
fi

echo "[INFO] Waiting for install cert-manager"
# Reference: https://cert-manager.io/v1.7-docs/installation/verify/
cmctl check api --wait=5m
kubectl apply -f "$CERT_MANAGER_CLUSTER_ISSUE_FILE"

# kube-pires
kubectl -n argocd apply -f helm-apps/kube-pires/application.yaml

# victoria-metrics cluster-mode
kubectl -n argocd apply -f helm-apps/victoriametrics-cluster-mode/application.yaml

# kube-prometheus-stack
# Install CRDs
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$KUBE_PROMETHEUS_STACK_VERSION/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml"

kubectl -n argocd apply -f helm-apps/kube-prometheus-stack/application.yaml


# Add entry in /etc/hosts for kube-pires
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/kube-pires --timeout=900s -n myapps
export IP=$(kubectl get ing kube-pires -n myapps -o json | jq -r .status.loadBalancer.ingress[].ip)
sudo grep -qxF "$IP  $KUBE_PIRES_DNS" /etc/hosts || sudo sh -c "echo '$IP  $KUBE_PIRES_DNS' >> /etc/hosts"

# Add entry in /etc/hosts for argocd
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/argocd-server --timeout=900s -n argocd
export IP=$(kubectl get ing argocd -n myapps -o json | jq -r .status.loadBalancer.ingress[].ip)
sudo grep -qxF "$IP  $ARGOCD_DNS" /etc/hosts || sudo sh -c "echo '$IP  $ARGOCD_DNS' >> /etc/hosts"
#-----------------------------------------------
