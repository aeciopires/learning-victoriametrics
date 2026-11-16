# install-metrics-server

<!-- TOC -->

- [install-metrics-server](#install-metrics-server)
- [Requirements](#requirements)
- [About](#about)
- [Troubleshooting](#troubleshooting)
- [References](#references)

<!-- TOC -->

# Requirements

- Install all packages and binaries following the instructions on the [REQUIREMENTS.md](../../REQUIREMENTS.md) file.
- Create the cluster following the instructions on the [README.md](../../README.md#create-cluster-and-deploy-applications) file.

# About

[metrics-server](https://github.com/kubernetes-sigs/metrics-server) collects CPU and memory usage from the kubelets and serves the resource metrics API (`metrics.k8s.io`). This API is used by:

- the HorizontalPodAutoscalers, such as the one of [kube-pires](../kube-pires/README.md). Without metrics-server, the HPA can't compute the number of replicas and ArgoCD reports the application as `Degraded`;
- the ``kubectl top`` command.

The kubelets of kind use self-signed serving certificates, so [values.yaml](values.yaml) adds the `--kubelet-insecure-tls` argument. Use it only in local/lab clusters.

# Troubleshooting

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -A
kubectl get hpa -A
```

# References

- https://github.com/kubernetes-sigs/metrics-server
- https://artifacthub.io/packages/helm/metrics-server/metrics-server
- https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/
