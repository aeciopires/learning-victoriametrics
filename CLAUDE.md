# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A homelab/learning environment for VictoriaMetrics, VictoriaLogs and VictoriaTraces (all in cluster mode) on Kubernetes. It is not an application with source code to compile — it is a GitOps configuration repo: a `kind` cluster is bootstrapped locally, then ArgoCD deploys and manages a set of Helm-based applications from this same repo (App-of-Apps style, ArgoCD watching this GitHub repo directly).

## Commands

```bash
make up        # check requirements, then run ./run.sh: create kind cluster + install everything
make down      # delete the kind cluster (kind delete clusters kind-multinodes)
make recreate  # down then up
```

- `make requirements` checks that `docker`, `wget`, `curl`, `kind`, `jq`, `argocd`, `cmctl` are installed (fails via `$(error ...)` if any is missing). Full install instructions per OS are in [softwares-ubuntu.md](softwares-ubuntu.md) and [softwares-macos.md](softwares-macos.md) (see [REQUIREMENTS.md](REQUIREMENTS.md)).
- There is no build/lint/test tooling (no compiler, package manager, or test suite) — validation is done by actually running `make up` against a local kind cluster and checking resources with `kubectl`/`argocd`.
- `run.sh` is idempotent-ish: it checks for existing kind clusters, existing Helm releases, and existing generated files under `/tmp` before acting, so it's normally safe to re-run.

## Architecture

`run.sh` does two kinds of installs:

1. **Bootstrap infra (installed directly via `helm upgrade --install`, not via ArgoCD):** MetalLB (LoadBalancer support for kind, with `strictARP` enabled on kube-proxy) and ArgoCD itself. ArgoCD's initial admin password is rotated to `changeme` and two repos are registered with `argocd repo add`: this repo (`learning-victoriametrics`) and an external `kube-pires` repo (a separate demo app, GitLab-hosted).
2. **Everything else, installed via ArgoCD Applications** (`kubectl -n argocd apply -f helm-apps/<app>/application.yaml`): ingress-nginx, cert-manager (+ a `ClusterIssuer` for Let's Encrypt HTTP-01), victoriametrics-cluster-mode, victorialogs-cluster-mode, victoriatraces, kube-prometheus-stack (Prometheus Operator CRDs are applied manually first, pinned to `KUBE_PROMETHEUS_STACK_VERSION`), and kube-pires (a sample app deployed into the `myapps` namespace).

Each `helm-apps/<name>/` directory follows the same shape:
- `application.yaml` — the ArgoCD `Application` manifest. Uses `sources` (plural) with two entries: the upstream Helm chart repo/version, and this Git repo as the `ref: values` source supplying `helm-apps/<name>/values.yaml`. `syncPolicy.automated` has `prune: true` / `selfHeal: true`, and most apps use `argocd.argoproj.io/sync-wave` annotations to sequence installation (e.g. victoriametrics-cluster-mode is wave `"6"`).
- `values.yaml` — Helm values passed to the upstream chart, generated from `helm show values <chart>` and then trimmed down (the VictoriaMetrics/VictoriaLogs/VictoriaTraces cluster-mode ones are large, 800–1300+ lines).
- `README.md` — per-app docs: architecture, access URLs (`*.mycompany.com`), internal write/read API endpoints, troubleshooting `kubectl` commands.

All ingress hostnames follow the pattern `<service>.mycompany.com` (`DOMAIN_NAME` in `run.sh`) and `run.sh` appends the resolved LoadBalancer IPs to `/etc/hosts` at the end of the run (requires `sudo`), after `kubectl wait --for=create ingress/...` on each app.

**VictoriaMetrics cluster mode** = vminsert (write, port 8480) / vmselect (read, port 8481) / vmstorage. **VictoriaLogs cluster mode** = vlinsert (port 9481) / vlselect (port 9471) / vlstorage. **VictoriaTraces cluster mode** = vtinsert (port 10481) / vtselect (port 10471) / vtstorage. Only victoriametrics-cluster-mode runs its own **vmauth** (an HTTP proxy/router), which fronts all three products behind a single shared ingress at `victoriametrics-cluster.mycompany.com`; VictoriaLogs and VictoriaTraces ship with `vmauth.enabled: false` and are instead reached through per-user HTTP Basic Auth entries (`vmauth.config.users` in [helm-apps/victoriametrics-cluster-mode/values.yaml](helm-apps/victoriametrics-cluster-mode/values.yaml)) whose `url_prefix` points at that product's internal `*.monitoring.svc.cluster.local` service — there is intentionally no per-product ingress hostname. See [helm-apps/victoriametrics-cluster-mode/README.md](helm-apps/victoriametrics-cluster-mode/README.md), [helm-apps/victorialogs-cluster-mode/README.md](helm-apps/victorialogs-cluster-mode/README.md) and [helm-apps/victoriatraces/README.md](helm-apps/victoriatraces/README.md) for exact DNS names and API paths.

Architecture diagrams: `images/vm-vl-cluster-arch.png`, `images/tools-used.png`, `images/request-workflow.png` (referenced from [README.md](README.md)).

## Making changes

- Software/chart version bumps live in several places that must stay in sync: the `targetRevision` (chart version) in each `application.yaml`, explicit `image.tag` overrides inside the corresponding `helm-apps/<app>/values.yaml` (e.g. `global.image.vm.tag`, `common.image.tag`, ArgoCD's `global.image.tag`), and the pinned version vars at the top of `run.sh` (`METALLB_CHART_VERSION`, `ARGOCD_CHART_VERSION`, `KUBE_PROMETHEUS_STACK_VERSION` — note this last one is actually the Prometheus-Operator release tag used for the manually-applied CRDs, and must match the operator version bundled by the kube-prometheus-stack chart). [CONTRIBUTING.md](CONTRIBUTING.md) has a full "Testing and upgrading software versions" checklist, and a "Adding a new VictoriaMetrics-ecosystem Helm app" recipe for onboarding new products the same way `victoriatraces` was added.
- [CHANGELOG.md](CHANGELOG.md) is maintained manually per release, listing bumped component/chart versions — update it when bumping versions.
- Both README.md and CHANGELOG.md use an inline `<!-- TOC -->...<!-- TOC -->` block that is kept in sync with headings by hand.
- Contribution workflow is fork-based (not branch-on-upstream): see [CONTRIBUTING.md](CONTRIBUTING.md) for the full fork/branch/PR/upstream-sync flow. PRs target `main` and are squash-merged; keep incremental commits during review rather than force-pushing/squashing locally (per [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md)).
