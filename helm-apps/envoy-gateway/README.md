# install-envoy-gateway

<!-- TOC -->

- [install-envoy-gateway](#install-envoy-gateway)
- [Requirements](#requirements)
- [About](#about)
- [Troubleshooting](#troubleshooting)
- [References](#references)

<!-- TOC -->

# Requirements

- Install all packages and binaries following the instructions on the [REQUIREMENTS.md](../../REQUIREMENTS.md) file.
- Create the cluster following the instructions on the [README.md](../../README.md#create-cluster-and-deploy-applications) file.

# About

[Envoy Gateway](https://gateway.envoyproxy.io/) is the [Gateway API](https://gateway-api.sigs.k8s.io/) implementation of this lab (it replaces ingress-nginx). It's installed by ArgoCD from the Helm chart published as an OCI artifact (`oci://docker.io/envoyproxy/gateway-helm`), which also installs:

- the Gateway API CRDs (standard channel), such as `GatewayClass`, `Gateway` and `HTTPRoute`;
- the Envoy Gateway CRDs, such as `EnvoyProxy`, `ClientTrafficPolicy`, `BackendTrafficPolicy` and `SecurityPolicy`.

The CRDs are too big for client-side apply, so [application.yaml](application.yaml) uses the `ServerSideApply=true` sync option.

This app only installs the controller (control plane). The `GatewayClass`, the `Gateway` and the HTTPRoutes are in the [gateway-api](../gateway-api/README.md) app. For each `Gateway`, Envoy Gateway creates an Envoy proxy Deployment (data plane) and a `LoadBalancer` Service in the `envoy-gateway-system` namespace. MetalLB gives the IP of this Service.

# Troubleshooting

List the resources.

```bash
kubectl get all -n envoy-gateway-system
kubectl get crd | grep -E 'gateway.networking.k8s.io|gateway.envoyproxy.io'
```

See the logs of the controller.

```bash
kubectl logs -n envoy-gateway-system deployment/envoy-gateway
```

# References

- https://gateway.envoyproxy.io/docs/
- https://gateway.envoyproxy.io/docs/install/install-helm/
- https://gateway.envoyproxy.io/docs/install/install-argocd/
- https://gateway.envoyproxy.io/docs/install/gateway-helm-api/
- https://github.com/envoyproxy/gateway
