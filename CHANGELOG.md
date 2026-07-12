# Changelog

<!-- TOC -->

- [Changelog](#changelog)
- [1.2.0](#120)
- [1.1.0](#110)
- [1.0.0](#100)

<!-- TOC -->

# 1.2.0

Date: 2026/07/12

> This homelab was tested in Ubuntu 22.04 64 bits

- Added VictoriaTraces cluster mode (`helm-apps/victoriatraces`), exposed through the shared vmauth from VictoriaMetrics cluster mode (`user-traces-insert` / `user-traces-select` users) instead of its own ingress, following the same pattern as VictoriaLogs
- Fixed VictoriaLogs README documentation that referenced a separate `vmauth`/ingress hostname that was never actually created; it now correctly documents the shared `victoriametrics-cluster.mycompany.com` ingress
- Documentation updated: added a "Testing and upgrading software versions" and an "Adding a new VictoriaMetrics-ecosystem Helm app" section to CONTRIBUTING.md
- Bump software versions:
  - kind node image: v1.32.2 -> v1.35.5
  - MetalLB: 0.14.9 -> 0.16.1
  - ArgoCD: 3.0.0 -> 3.4.5
    - helm chart: 8.0.1 -> 10.1.3
  - cert-manager: v1.17.2 -> v1.21.0
  - Ingress-Nginx: 4.12.2 -> 4.15.1 (app 1.15.1)
  - VictoriaMetrics Cluster (all components): 1.117.0 -> 1.147.0
    - helm chart: 0.22.0 -> 0.46.0
  - VictoriaLogs Cluster (all components): 1.22.2 -> 1.51.0
    - helm chart: 0.0.2 -> 0.2.7
  - VictoriaTraces Cluster (all components): new, v0.9.4
    - helm chart: 0.2.9
  - kube-prometheus-stack: 72.3.1 -> 87.15.1
  - Prometheus-Operator: v0.82.0 -> v0.92.1

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


