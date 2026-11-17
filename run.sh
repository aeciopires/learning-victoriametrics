#!/bin/bash
# if use Ubuntu

#!/opt/homebrew/bin/bash
# if use MacOS with brew

#------------------------
# Variables
DOMAIN_NAME="mycompany.com"
CLUSTER_NAME="kind-multinodes"
KIND_CLUSTER_FILE="/tmp/kind-cluster.yaml"
METALLB_CHART_VERSION="0.16.2"
METALLB_FILE="/tmp/metallb-ingress-address.yaml"
CERT_MANAGER_CLUSTER_ISSUE_FILE="/tmp/cert-cluster-issue.yaml"
ARGOCD_CHART_VERSION="10.18.0"
ARGOCD_USER="admin"
ARGOCD_INITIAL_PASS="changeme"
ARGOCD_DNS="argocd.${DOMAIN_NAME}"
# Also used as the Prometheus Operator CRDs release tag applied below; must match the
# prometheus-operator version bundled by the kube-prometheus-stack chart (see its appVersion).
KUBE_PROMETHEUS_STACK_VERSION="v0.95.2"
KUBE_PIRES_DNS="kube-pires.${DOMAIN_NAME}"
ALERTMANAGER_DNS="alertmanager.${DOMAIN_NAME}"
GRAFANA_DNS="grafana.${DOMAIN_NAME}"
PROMETHEUS_DNS="prometheus.${DOMAIN_NAME}"
VICTORIAMETRICS_CLUSTER_MODE_DNS="victoriametrics-cluster.${DOMAIN_NAME}"
# Gateway API Gateway (Envoy Gateway) that exposes every application (helm-apps/gateway-api)
GATEWAY_NAME="mycompany-gateway"
GATEWAY_NAMESPACE="envoy-gateway-system"
# Minimum inotify limits recommended by kind for multi-node clusters
# https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files
INOTIFY_MAX_USER_WATCHES="524288"
INOTIFY_MAX_USER_INSTANCES="512"
#------------------------



#---------------------------------------
# Checking Helm version
#---------------------------------------

# This repository requires Helm 4 (see REQUIREMENTS.md)
HELM_VERSION=$(helm version --template '{{.Version}}' 2>/dev/null)
if [[ "$HELM_VERSION" != v4.* ]]; then
  echo "[ERROR] Helm 4 is required, found: ${HELM_VERSION:-none}"
  exit 1
fi
echo "[INFO] Using Helm $HELM_VERSION"
#-----------------------------------------------


#---------------------------------------
# Checking inotify limits (Linux only)
#---------------------------------------

# kind nodes share the host kernel inotify limits. With the default values (128 instances)
# pods like Vector (victorialogs) crash with "Too many open files".
# This raises the limits only until the next reboot. To make it permanent, see softwares-ubuntu.md.
if [ "$(uname -s)" = "Linux" ]; then
  CURRENT_WATCHES=$(cat /proc/sys/fs/inotify/max_user_watches)
  CURRENT_INSTANCES=$(cat /proc/sys/fs/inotify/max_user_instances)
  if [ "$CURRENT_WATCHES" -lt "$INOTIFY_MAX_USER_WATCHES" ] || [ "$CURRENT_INSTANCES" -lt "$INOTIFY_MAX_USER_INSTANCES" ]; then
    echo "[WARNING] inotify limits too low for kind (max_user_watches=$CURRENT_WATCHES, max_user_instances=$CURRENT_INSTANCES). Raising them with sudo until the next reboot."
    sudo sysctl -w "fs.inotify.max_user_watches=$INOTIFY_MAX_USER_WATCHES" "fs.inotify.max_user_instances=$INOTIFY_MAX_USER_INSTANCES" || exit 1
  fi
fi
#-----------------------------------------------


#---------------------------------------
# Creating kind Kubernetes cluster
#---------------------------------------

if [ ! -f "$KIND_CLUSTER_FILE" ]; then

  cat << EOF > "$KIND_CLUSTER_FILE"
# References:
# Kind release image: https://github.com/kubernetes-sigs/kind/releases
# Configuration: https://kind.sigs.k8s.io/docs/user/configuration/
# Metal LB in Kind: https://kind.sigs.k8s.io/docs/user/loadbalancer
# Envoy Gateway in Kind: https://gateway.envoyproxy.io/docs/tasks/quickstart/

# Config compatible with kind v0.33.0
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
  - role: control-plane
    image: kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "nodeapp=loadbalancer"
    # No extraPortMappings (hostPort 80/443): the applications are reached through the
    # LoadBalancer IP of the Envoy Gateway (MetalLB), so this cluster doesn't conflict
    # with other kind clusters already using the host ports 80/443
  - role: worker
    image: kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
  - role: worker
    image: kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
EOF

else
  echo "[WARNING] $KIND_CLUSTER_FILE file already exists"
fi


if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "[WARNING] Kind cluster already exists"
else
  if ! kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CLUSTER_FILE"; then
    echo "[ERROR] Failed to create kind cluster $CLUSTER_NAME (are ports 80/443 already used by another kind cluster?)"
    exit 1
  fi
fi

# Make sure every kubectl/helm command below targets the kind cluster,
# never the previously active context (e.g. another cluster)
if ! kubectl config use-context "kind-${CLUSTER_NAME}"; then
  echo "[ERROR] kubectl context kind-${CLUSTER_NAME} not found"
  exit 1
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
  KIND_ADDRESS=$(docker network inspect kind | jq -r '.[].IPAM.Config[] | select(.Subnet | test("^[0-9]+\\.")) | .Subnet' | cut -d"." -f1-3)

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

  # Waiting creation some ArgoCD resources
  kubectl wait --for=create secret/argocd-initial-admin-secret --timeout=900s -n argocd
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=900s -n argocd
  # Change initial password
  INITIAL_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  argocd login --username $ARGOCD_USER --server-name argocd-server --port-forward --port-forward-namespace argocd --plaintext --insecure --password "$INITIAL_PASS"
  argocd account update-password --server-name argocd-server --current-password "$INITIAL_PASS" --new-password "$ARGOCD_INITIAL_PASS" --port-forward --port-forward-namespace argocd
  kubectl -n argocd delete secret argocd-initial-admin-secret
  # Adding repositories
  argocd repo add https://github.com/aeciopires/learning-victoriametrics --name learning-victoriametrics --type git --project default --server-name argocd-server --port-forward --port-forward-namespace argocd --plaintext --insecure
  argocd repo add https://gitlab.com/aeciopires/kube-pires.git --name kube-pires --type git --project default  --server-name argocd-server --port-forward --port-forward-namespace argocd --plaintext --insecure
fi
#-----------------------------------------------



#---------------------------------------
# Install/Sync other apps using ArgoCD
#---------------------------------------

# Envoy Gateway (Gateway API implementation). Also installs the Gateway API CRDs,
# which must exist before cert-manager starts with Gateway API support enabled.
kubectl -n argocd apply -f helm-apps/envoy-gateway/application.yaml
echo "[INFO] Waiting for install envoy-gateway"
kubectl wait --for=create crd/gateways.gateway.networking.k8s.io --timeout=900s
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io crd/httproutes.gateway.networking.k8s.io --timeout=300s
kubectl wait --for=create deployment/envoy-gateway --timeout=900s -n "$GATEWAY_NAMESPACE"
kubectl wait --for=condition=Available deployment/envoy-gateway --timeout=900s -n "$GATEWAY_NAMESPACE"

# certificate-manager
kubectl -n argocd apply -f helm-apps/cert-manager/application.yaml

# Let's Encrypt ClusterIssuer (HTTP-01 challenge solved through the Gateway with an HTTPRoute).
# Example only: Let's Encrypt can't validate the private domain used in this lab and the email must be valid.
# The Gateway uses the local CA ClusterIssuer "mycompany-local-ca" (helm-apps/gateway-api) instead.
cat << EOF2 > "$CERT_MANAGER_CLUSTER_ISSUE_FILE"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-http01
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: group@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-http01
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: $GATEWAY_NAME
            namespace: $GATEWAY_NAMESPACE
            kind: Gateway
            sectionName: http
EOF2

echo "[INFO] Waiting for install cert-manager"
# Reference: https://cert-manager.io/docs/installation/verify/
cmctl check api --wait=5m
kubectl apply -f "$CERT_MANAGER_CLUSTER_ISSUE_FILE"

# Gateway API resources: local CA, GatewayClass, Gateway, HTTP -> HTTPS redirect and ArgoCD HTTPRoute
kubectl -n argocd apply -f helm-apps/gateway-api/application.yaml
echo "[INFO] Waiting for the Gateway $GATEWAY_NAME"
kubectl wait --for=create "gateway/$GATEWAY_NAME" --timeout=900s -n "$GATEWAY_NAMESPACE"
kubectl wait --for=condition=Programmed "gateway/$GATEWAY_NAME" --timeout=900s -n "$GATEWAY_NAMESPACE"

# metrics-server (resource metrics API used by the HorizontalPodAutoscalers and "kubectl top")
kubectl -n argocd apply -f helm-apps/metrics-server/application.yaml

# victoriametrics cluster-mode
kubectl -n argocd apply -f helm-apps/victoriametrics-cluster-mode/application.yaml

# victorialogs cluster-mode
kubectl -n argocd apply -f helm-apps/victorialogs-cluster-mode/application.yaml

# victoriatraces cluster-mode
kubectl -n argocd apply -f helm-apps/victoriatraces-cluster-mode/application.yaml

# Install CRDs prometheus
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

# kube-prometheus-stack
kubectl -n argocd apply -f helm-apps/kube-prometheus-stack/application.yaml

# kube-pires
kubectl -n argocd apply -f helm-apps/kube-pires/application.yaml

# Wait for the HTTPRoutes of every application to be accepted by the Gateway
echo "[INFO] Waiting for the HTTPRoutes"
for ROUTE in argocd/argocd-server myapps/kube-pires monitoring/monitor-mycompany-alertmanager \
             monitoring/monitor-grafana monitoring/monitor-mycompany-prometheus \
             monitoring/victoria-metrics-victoria-metrics-cluster-vmauth; do
  kubectl wait --for=create "httproute/${ROUTE#*/}" --timeout=900s -n "${ROUTE%%/*}"
  kubectl wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
    "httproute/${ROUTE#*/}" --timeout=300s -n "${ROUTE%%/*}"
done

# Add entries in /etc/hosts: every hostname points to the address of the Gateway (LoadBalancer IP from MetalLB)
GATEWAY_IP=$(kubectl get gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" -o jsonpath='{.status.addresses[0].value}')
if [ -z "$GATEWAY_IP" ]; then
  echo "[ERROR] Gateway $GATEWAY_NAME has no address, /etc/hosts not updated"
  exit 1
fi
for DNS in "$KUBE_PIRES_DNS" "$ARGOCD_DNS" "$ALERTMANAGER_DNS" "$GRAFANA_DNS" "$PROMETHEUS_DNS" "$VICTORIAMETRICS_CLUSTER_MODE_DNS"; do
  sudo grep -qxF "$GATEWAY_IP  $DNS" /etc/hosts || sudo sh -c "echo '$GATEWAY_IP  $DNS' >> /etc/hosts"
done

echo "[INFO] Applications exposed by the Gateway $GATEWAY_NAME ($GATEWAY_IP) over HTTPS."
echo "[INFO] Trust the local CA to avoid browser warnings, see README.md:"
echo "kubectl -n cert-manager get secret mycompany-local-ca -o jsonpath='{.data.ca\\.crt}' | base64 -d > mycompany-local-ca.crt"
#-----------------------------------------------
