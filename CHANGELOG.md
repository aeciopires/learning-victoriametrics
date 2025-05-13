# Changelog

<!-- TOC -->

- [Changelog](#changelog)
- [1.1.0](#110)
- [1.0.0](#100)

<!-- TOC -->

# 1.1.0

Date: 2025/05/13

> This homelab was tested in Ubuntu 22.04 64 bits

- Documentation updated
- Added VictoriaLogs cluster mode
- Added datasource and plugins for VictoriaMetrics and VictoriaLogs
- Adjusted vmauth config to support VictoriaLogs components
- Bump software versions:
  - ArgoCD: 3.0.0
    - helm chart: 8.0.1
  - VictoriaMetrics Cluster (all components): 1.117.0
    - helm chart: 0.22.0
  - VictoriaLogs Cluster (all components): 1.22.2
    - helm chart: 0.0.2
  - Prometheus-Operator: v0.82.0
    - helm chart: 72.3.1

# 1.0.0

Date: 2025/05/09

> This homelab was tested in Ubuntu 22.04 64 bits

- Initial version
- Created documentation
- Created Makefile and shell script for automation
- Created images
- Created dashboard of kube-pires
- Software versions:
  - Kind: 0.27.0
  - Kubernetes: 1.32.0
  - MetalLB: 0.14.9
  - ArgoCD: 3.0.0
  - VictoriaMetrics Cluster (all components): 1.116.0
  - Grafana: 12.0.0
  - AlertManager: 0.28.1
  - Prometheus: 3.3.1
  - Prometheus-Operator: v0.82.0
  - kube-pires: 1.1.0
  - Ingress-Nginx: 1.12.2
  - Cert-manager: 1.17.2


