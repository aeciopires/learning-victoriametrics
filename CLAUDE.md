# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A homelab/learning environment for VictoriaMetrics, VictoriaLogs and VictoriaTraces (all in cluster mode) on Kubernetes. It is not an application with source code to compile — it is a GitOps configuration repo: a `kind` cluster is bootstrapped locally, then ArgoCD deploys and manages a set of Helm-based applications from this same repo (App-of-Apps style, ArgoCD watching this GitHub repo directly).

## Commands

```bash
make up           # check requirements + mise install, then "mise exec -- ./run.sh": create kind cluster + install everything
make down          # delete the kind cluster and the files run.sh generated in /tmp
make recreate      # down then up
make tools         # mise install
make helm-plugins  # optional: mise run helm-plugins (helm-diff, helm-secrets)
```

- Tooling is managed by **mise** (never asdf): `kind`, `kubectl`, `helm`, `argocd`, `cmctl`, `jq` are pinned in [mise.toml](mise.toml) with explicit `aqua:` backends, and the Makefile runs `run.sh`/`kind` through `mise exec --`, so whatever is in the user's `PATH` doesn't matter. Only Docker (+ compose plugin) on Ubuntu (22.04/24.04/26.04 LTS; `make requirements` warns on other Ubuntu versions via `SUPPORTED_UBUNTU_VERSIONS` in the Makefile) or Colima + docker CLI + docker-compose on MacOS, mise itself, `make`, `curl`, `gpg` and `sudo` are installed outside of mise. `make requirements` checks those, checks that docker is running, runs `mise install` and verifies `helm` is **Helm 4** (`run.sh` repeats the check; Helm 3 is not supported). The `helm-plugins` mise task installs helm-diff/helm-secrets from signed release tarballs (Helm 4 has no `--version` for plugins). [REQUIREMENTS.md](REQUIREMENTS.md) holds what is common to every OS (tools of mise with their versions, Helm plugins, kind, inotify limits, optionals); [softwares-ubuntu.md](softwares-ubuntu.md) and [softwares-macos.md](softwares-macos.md) hold only the OS-specific steps (packages, container runtime, mise install, how to persist the inotify limits).
- There is no build/lint/test tooling (no compiler, package manager, or test suite) — validation is done by actually running `make up` against a local kind cluster and checking resources with `kubectl`/`argocd`.
- `run.sh` is idempotent-ish: it checks for existing kind clusters, existing Helm releases, and existing generated files under `/tmp` before acting, so it's normally safe to re-run.

## Architecture

`run.sh` does two kinds of installs:

1. **Bootstrap infra (installed directly via `helm upgrade --install`, not via ArgoCD):** MetalLB (LoadBalancer support for kind, with `strictARP` enabled on kube-proxy) and ArgoCD itself. ArgoCD's initial admin password is rotated to `changeme` and two repos are registered with `argocd repo add`: this repo (`learning-victoriametrics`) and an external `kube-pires` repo (a separate demo app, GitLab-hosted).
2. **Everything else, installed via ArgoCD Applications** (`kubectl -n argocd apply -f helm-apps/<app>/application.yaml`), in this order with `kubectl wait` between them: envoy-gateway (Envoy Gateway controller + Gateway API CRDs, OCI chart, `ServerSideApply=true`), cert-manager (with `config.gatewayAPI.enabled: true`, so it must start after the Gateway API CRDs exist; `run.sh` also applies an example Let's Encrypt `ClusterIssuer` that stays not-ready in this lab), gateway-api (plain manifests in `helm-apps/gateway-api/manifests`, no chart: local CA issuers, `GatewayClass`, the `mycompany-gateway` `Gateway` in `envoy-gateway-system`, the HTTP→HTTPS redirect and the ArgoCD `HTTPRoute`), metrics-server (needed by the HPAs, otherwise ArgoCD reports them Degraded), victoriametrics-cluster-mode, victorialogs-cluster-mode, victoriatraces-cluster-mode, kube-prometheus-stack (Prometheus Operator CRDs are applied manually first, pinned to `KUBE_PROMETHEUS_STACK_VERSION`), and kube-pires (a sample app deployed into the `myapps` namespace).

Each `helm-apps/<name>/` directory follows the same shape:
- `application.yaml` — the ArgoCD `Application` manifest. Uses `sources` (plural) with two entries: the upstream Helm chart repo/version, and this Git repo as the `ref: values` source supplying `helm-apps/<name>/values.yaml`. `syncPolicy.automated` has `prune: true` / `selfHeal: true`, and most apps use `argocd.argoproj.io/sync-wave` annotations to sequence installation (e.g. victoriametrics-cluster-mode is wave `"6"`).
- (`gateway-api/` is the exception: a `manifests/` directory synced as plain manifests, no `values.yaml`.)
- `values.yaml` — Helm values passed to the upstream chart, generated from `helm show values <chart>` and then trimmed down (the VictoriaMetrics/VictoriaLogs/VictoriaTraces cluster-mode ones are large, 800–1300+ lines).
- `README.md` — per-app docs: architecture, access URLs (`*.mycompany.com`), internal write/read API endpoints, troubleshooting `kubectl` commands.

There is no Ingress controller: every app is exposed through Gateway API `HTTPRoute`s attached to the `https` listener (`sectionName: https`) of `mycompany-gateway` (namespace `envoy-gateway-system`), declared via each chart's route values (`grafana.route.main`, `prometheus.route.main`, `alertmanager.route.main`, `vmauth.route`), via `extraManifests` for kube-pires, and in `helm-apps/gateway-api/manifests` for ArgoCD (installed before the CRDs exist). The listener only accepts routes from the `argocd`, `monitoring` and `myapps` namespaces. TLS is terminated at the Gateway with a `*.mycompany.com` certificate signed by the local CA `ClusterIssuer` `mycompany-local-ca` (Let's Encrypt can't validate the private domain). All hostnames follow `<service>.mycompany.com` (`DOMAIN_NAME` in `run.sh`); `run.sh` waits for each `HTTPRoute` to be `Accepted`, then appends the Gateway address (`Gateway.status.addresses`, a MetalLB IP) to `/etc/hosts` (requires `sudo`). `run.sh` also raises the host inotify limits with `sudo sysctl -w` on Linux when they are below kind's recommendation (otherwise Vector crashes with "Too many open files"), aborts if `kind create cluster` fails and pins the `kind-kind-multinodes` kubectl context so it never touches another cluster.

**VictoriaMetrics cluster mode** = vminsert (write, port 8480) / vmselect (read, port 8481) / vmstorage. **VictoriaLogs cluster mode** = vlinsert (port 9481) / vlselect (port 9471) / vlstorage. **VictoriaTraces cluster mode** = vtinsert (port 10481) / vtselect (port 10471) / vtstorage. Only victoriametrics-cluster-mode runs its own **vmauth** (an HTTP proxy/router), which fronts all three products behind a single shared HTTPRoute at `victoriametrics-cluster.mycompany.com`; VictoriaLogs and VictoriaTraces ship with `vmauth.enabled: false` and are instead reached through per-user HTTP Basic Auth entries (`vmauth.config.users` in [helm-apps/victoriametrics-cluster-mode/values.yaml](helm-apps/victoriametrics-cluster-mode/values.yaml)) whose `url_prefix` points at that product's internal `*.monitoring.svc.cluster.local` service — there is intentionally no per-product hostname. See [helm-apps/victoriametrics-cluster-mode/README.md](helm-apps/victoriametrics-cluster-mode/README.md), [helm-apps/victorialogs-cluster-mode/README.md](helm-apps/victorialogs-cluster-mode/README.md) and [helm-apps/victoriatraces-cluster-mode/README.md](helm-apps/victoriatraces-cluster-mode/README.md) for exact DNS names and API paths.

Architecture diagrams: `images/vm-vl-cluster-arch.png`, `images/tools-used.png`, `images/request-workflow.png` (referenced from [README.md](README.md)).

## Making changes

- Software/chart version bumps live in several places that must stay in sync: the `targetRevision` (chart version) in each `application.yaml`, explicit `image.tag` overrides inside the corresponding `helm-apps/<app>/values.yaml` (e.g. `global.image.vm.tag`, `common.image.tag`, ArgoCD's `global.image.tag`), and CLI versions in [mise.toml](mise.toml), and the pinned version vars at the top of `run.sh` (`METALLB_CHART_VERSION`, `ARGOCD_CHART_VERSION`, `KUBE_PROMETHEUS_STACK_VERSION` — note this last one is actually the Prometheus-Operator release tag used for the manually-applied CRDs, and must match the operator version bundled by the kube-prometheus-stack chart). [CONTRIBUTING.md](CONTRIBUTING.md) has a full "Testing and upgrading software versions" checklist, and a "Adding a new VictoriaMetrics-ecosystem Helm app" recipe for onboarding new products the same way `victoriatraces` was added.
- [CHANGELOG.md](CHANGELOG.md) is maintained manually per release, listing bumped component/chart versions — update it when bumping versions.
- Both README.md and CHANGELOG.md use an inline `<!-- TOC -->...<!-- TOC -->` block that is kept in sync with headings by hand.
- Contribution workflow is fork-based (not branch-on-upstream): see [CONTRIBUTING.md](CONTRIBUTING.md) for the full fork/branch/PR/upstream-sync flow. PRs target `main` and are squash-merged; keep incremental commits during review rather than force-pushing/squashing locally (per [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md)).
