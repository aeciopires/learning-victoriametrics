# Changelog

<!-- TOC -->

- [Changelog](#changelog)
- [1.4.0](#140)
- [1.3.0](#130)
- [1.2.0](#120)
- [1.1.0](#110)
- [1.0.0](#100)

<!-- TOC -->

# 1.4.0

Date: 2026/11/16

> This homelab was tested in Ubuntu 22.04 64 bits

- Bump software versions:
  - ArgoCD: kept at 3.6.1
    - helm chart: 10.12.1 -> 10.18.0
  - VictoriaMetrics Cluster (all components): 1.155.0 -> 1.156.0
    - helm chart: 0.54.0 -> 0.55.0
  - VictoriaLogs Cluster (all components): 1.53.0 -> 1.54.0
    - helm chart: 0.2.11 -> 0.2.12
  - VictoriaTraces Cluster (all components): v0.12.1 -> v0.13.0
    - helm chart: 0.2.12 -> 0.2.13
    - vmauth image: v1.155.0 -> v1.156.0
    - removed the `tlsAutocertHosts` / `tlsAutocertEmail` / `tlsAutocertCacheDir` values, dropped upstream in this chart version
  - kube-prometheus-stack: 92.18.0 -> 93.3.1
    - Grafana: 13.3.0 -> 13.3.1 (grafana helm chart 14.3.1 -> 14.4.2)
    - Prometheus: v3.15.1 -> v3.16.0
  - Prometheus-Operator: v0.94.2 -> v0.95.2
  - kube-pires: 1.1.0 -> 2.0.0
    - helm chart: `HEAD` of the Git repository -> tag `v7.0.0` (chart 4.0.0), now pinned
    - values.yaml regenerated from the chart defaults, keeping only the customizations of this lab (HPA with 2 min replicas, ServiceMonitor, PDB and the HTTPRoute). New defaults: probes on `/livez` and `/readyz`, graceful shutdown (`config.shutdownDelay: 10s`), `podSecurityContext`/`securityContext` following the "Restricted" Pod Security Standard (non-root `65532`, read-only root filesystem), requests 10m/32Mi and limit 128Mi
  - Unchanged (already latest): kind 0.33.0 / node image v1.37.0, MetalLB 0.16.2, cert-manager v1.21.3
- **Support for Ubuntu 26.04 LTS** (besides 24.04 and 22.04):
  - softwares-ubuntu.md: lists the supported versions, installs `python-is-python3` instead of the per-version `update-alternatives` commands (the Python version differs on each release), makes `telnet` optional and adds notes about sudo-rs and uutils coreutils, the defaults on 26.04
  - softwares-ubuntu.md: documents the `docker.io` + `docker-compose-v2` packages of the Ubuntu archive as an alternative to the Docker CE convenience script
  - `make requirements` prints a warning on Ubuntu versions not listed in `SUPPORTED_UBUNTU_VERSIONS` (Makefile)
- Requirements docs reorganized: REQUIREMENTS.md now holds everything common to Ubuntu and MacOS (supported OSes, tools installed by mise with their versions, Helm plugins, kind, inotify limits, optional software and VSCode plugins), and softwares-ubuntu.md / softwares-macos.md keep only the OS-specific steps
- softwares-macos.md fixes: `softwareupdate --install-rosetta` (was `software --install rosetta`), `~/.bash_profile` (was the nonexistent `/User/$USER/.bash_profile`) and `$PATH` no longer escaped inside single quotes. Visual Studio Code is installed with `brew install --cask`
- Migrated to **Helm 4**:
  - helm: 3.22.1 -> 4.3.2
  - `make requirements` (Makefile) and `run.sh` now check that `helm` is installed and is version 4
  - helm-diff and helm-secrets install instructions rewritten for Helm 4: plugins are installed from signed release tarballs with provenance verification (`--keyring`), since Helm 4 dropped `--version` for plugins. helm-secrets is now split into the `secrets`, `secrets-getter` and `secrets-post-renderer` plugins
- Bump CLI versions:
  - helm-secrets: v4.7.10 -> v4.7.11
- **Tools managed by [mise](https://mise.jdx.dev)** (replaces asdf and the manual installs of Go, cmctl and kubectl):
  - New `mise.toml` pinning `argocd` 3.6.1, `cmctl` 2.6.2, `helm` 4.3.2, `jq` 1.8.2, `kind` 0.33.0 and `kubectl` 1.37.2, all with the aqua backend
  - New mise task `helm-plugins` (`make helm-plugins`) installing helm-diff and helm-secrets for Helm 4 (signed tarballs, idempotent)
  - Makefile rewritten: `make requirements` checks only what is installed outside of mise (`mise`, `docker` running, `curl`, `gpg`, `sudo`), runs `mise install` and checks Helm 4; `run.sh` and `kind` run through `mise exec`. New targets `help`, `tools` and `helm-plugins`. `SHELL` uses the bash of the `PATH`, so the same Makefile works on Ubuntu and MacOS
  - Docker + compose plugin (Ubuntu) and Colima + docker CLI + docker-compose (MacOS, replaces Docker Desktop) are still installed outside of mise
  - softwares-ubuntu.md, softwares-macos.md and REQUIREMENTS.md rewritten for mise and Colima (including inotify limits and network notes for Colima)
- **Replaced ingress-nginx (retired project) with Envoy Gateway and the Gateway API**:
  - New app `helm-apps/envoy-gateway`: Envoy Gateway v1.10.0 (OCI chart `oci://docker.io/envoyproxy/gateway-helm`), which also installs the Gateway API CRDs v1.6.1
  - New app `helm-apps/gateway-api` (plain manifests): `GatewayClass`, `Gateway` `mycompany-gateway` with HTTP and HTTPS (`*.mycompany.com`) listeners, HTTP -> HTTPS redirect (`RequestRedirect` filter), `allowedRoutes` restricted to the `argocd`, `monitoring` and `myapps` namespaces, and the ArgoCD `HTTPRoute`
  - Every Ingress replaced by an `HTTPRoute`: Grafana, Prometheus and Alertmanager (`route.main` of kube-prometheus-stack), vmauth (`vmauth.route` of victoria-metrics-cluster), kube-pires (`extraManifests`) and ArgoCD
  - TLS terminated at the Gateway with a wildcard certificate issued by cert-manager (gateway-shim, `config.gatewayAPI.enabled: true`) from a new local CA (`ClusterIssuer` `mycompany-local-ca`). Before, no certificate was ever issued: the Let's Encrypt `ClusterIssuer` failed (invalid `example.com` email, and Let's Encrypt can't validate the private domain), and ingress-nginx served its self-signed fake certificate
  - The example Let's Encrypt `ClusterIssuer` now uses the `gatewayHTTPRoute` HTTP-01 solver
  - `run.sh` installs the apps in dependency order (envoy-gateway -> cert-manager -> gateway-api -> others), waits for the `Gateway` to be `Programmed` and every `HTTPRoute` to be `Accepted`, and writes the Gateway address (`status.addresses`) to `/etc/hosts`
  - Removed the `extraPortMappings` (host ports 80/443) of the kind control-plane node, unused since the traffic goes through the MetalLB IP, which conflicted with other kind clusters
  - Removed `helm-apps/ingress-nginx`
- New app `helm-apps/metrics-server` (chart 3.14.0, metrics-server 0.9.1 via `image.tag` override since the chart still bundles 0.9.0, `--kubelet-insecure-tls` for kind). Fixes the HPAs of ingress-nginx and kube-pires being reported as `Degraded` by ArgoCD, which made the ingress-nginx sync fail before configuring its admission webhook (`x509: certificate signed by unknown authority`) and blocked the Ingresses of the other apps
- `run.sh` fixes:
  - Raises the inotify limits of the host (Linux) when they are below the values recommended by kind, fixing Vector (VictoriaLogs) in `CrashLoopBackOff` with `Too many open files`. See the new "inotify limits" section of softwares-ubuntu.md to make it permanent
  - Aborts if `kind create cluster` fails and switches to the `kind-kind-multinodes` kubectl context, so it never installs anything in another cluster
- `make down` removes the files generated by `run.sh` in `/tmp`, so the next `make up` doesn't reuse stale configurations
- Documentation: added a VictoriaStack section to README.md, comparing it with this homelab. Updated README.md, CONTRIBUTING.md, CLAUDE.md and the READMEs of the apps for the Gateway API, and added the READMEs of envoy-gateway, gateway-api and metrics-server

# 1.3.0

Date: 2026/11/04

> This homelab was tested in Ubuntu 22.04 64 bits

- Bump software versions:
  - kind: 0.32.0 -> 0.33.0
  - kind node image (Kubernetes): v1.35.5 -> v1.37.0
  - MetalLB: 0.16.1 -> 0.16.2
  - ArgoCD: 3.4.5 -> 3.6.1
    - helm chart: 10.1.3 -> 10.12.1
  - cert-manager: v1.21.0 -> v1.21.3
  - VictoriaMetrics Cluster (all components): 1.147.0 -> 1.155.0
    - helm chart: 0.46.0 -> 0.54.0
  - VictoriaLogs Cluster (all components): 1.51.0 -> 1.53.0
    - helm chart: 0.2.7 -> 0.2.11
  - VictoriaTraces Cluster (all components): v0.9.4 -> v0.12.1
    - helm chart: 0.2.9 -> 0.2.12
    - vmauth image: v1.143.0 -> v1.155.0
  - kube-prometheus-stack: 87.15.1 -> 92.18.0
    - Grafana: 13.1.0 -> 13.3.0 (grafana helm chart 12.7.2 -> 14.3.1)
    - Prometheus: v3.3.1 -> v3.15.1
  - Prometheus-Operator: v0.92.1 -> v0.94.2
  - Ingress-Nginx: kept at 4.15.1 (app 1.15.1), the last release of the retired project
- Bump CLI versions in softwares-ubuntu.md and softwares-macos.md:
  - argocd CLI: 3.4.5 -> 3.6.1
  - helm: 3.21.2 -> 3.22.1
  - helm-diff: v3.15.10 -> v3.15.15
  - helm-secrets: v4.7.7 -> v4.7.10
  - kubectl: 1.36.2 -> 1.37.2
  - cmctl: v2.5.0 -> v2.6.2

# 1.2.0

Date: 2026/07/12

> This homelab was tested in Ubuntu 22.04 64 bits

- Added VictoriaTraces cluster mode (`helm-apps/victoriatraces-cluster-mode`), exposed through the shared vmauth from VictoriaMetrics cluster mode (`user-traces-insert` / `user-traces-select` users) instead of its own ingress, following the same pattern as VictoriaLogs
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
