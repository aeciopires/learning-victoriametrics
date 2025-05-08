#!/bin/bash
# Uncomment before line if use Ubuntu

#!/opt/homebrew/bin/bash
# Uncomment before line if use MacOS with brew

#------------------------
# Variables
CLUSTER_NAME="kind-multinodes"
KIND_CLUSTER_FILE="/tmp/kind-cluster.yaml"
METALLB_CHART_VERSION="0.14.9"
METALLB_FILE="/tmp/metallb-ingress-address.yaml"
INGRESS_NGINX_VERSION='4.12.2'
CERT_MANAGER_VERSION='v1.17.2'
CERT_MANAGER_CLUSTER_ISSUE_FILE="/tmp/cert-cluster-issue.yaml"
KUBE_PROMETHEUS_CHART_VERSION="72.2.0"
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
# Install Metallb
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
    --namespace metallb-system \
    --create-namespace \
    --version "$METALLB_CHART_VERSION" \
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
# Install ingress-nginx
#---------------------------------------
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version "$INGRESS_NGINX_VERSION" \
  --namespace ingress-nginx \
  --create-namespace \
  --debug=true \
  --wait \
  --timeout=900s \
  -f helm-apps/ingress-nginx/values.yaml
#-----------------------------------------------




#---------------------------------------
# Install certificate-manager
#---------------------------------------
helm repo add jetstack https://charts.jetstack.io

helm repo update

helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --debug=true \
  --wait \
  --timeout=900s \
  --version "$CERT_MANAGER_VERSION" --set global.leaderElection.namespace=cert-manager --set crds.enabled=true

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
#-----------------------------------------------





#---------------------------------------
# Install kube-prometheus-stack
#---------------------------------------

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

# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

helm upgrade --install prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version "$KUBE_PROMETHEUS_CHART_VERSION" \
  --create-namespace \
  --debug=true \
  --wait \
  --timeout=900s \
  -f helm-apps/kube-prometheus-stack/values.yaml
#-----------------------------------------------




#---------------------------------------
# Install kube-pires
#---------------------------------------
git clone https://gitlab.com/aeciopires/kube-pires /tmp/kube-pires

helm upgrade --install kube-pires /tmp/kube-pires/helm-chart \
  --namespace myapps \
  --create-namespace \
  --debug=true \
  --wait \
  --timeout=900s \
  -f helm-apps/kube-pires/values.yaml

# Add entry in /etc/hosts for kube-pires
export IP=$(kubectl get ing kube-pires -n myapps -o json | jq -r .status.loadBalancer.ingress[].ip)
sudo grep -qxF "$IP  $KUBE_PIRES_DNS" /etc/hosts || sudo sh -c "echo '$IP  $KUBE_PIRES_DNS' >> /etc/hosts"
#-----------------------------------------------

