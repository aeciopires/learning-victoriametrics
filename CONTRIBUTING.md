<!-- TOC -->

- [Contributing](#contributing)
- [Testing and upgrading software versions](#testing-and-upgrading-software-versions)
- [Adding a new VictoriaMetrics-ecosystem Helm app (e.g. VictoriaTraces)](#adding-a-new-victoriametrics-ecosystem-helm-app-eg-victoriatraces)

<!-- TOC -->

# Contributing

- Configure authentication on your Github account to use the SSH protocol instead of HTTP. Watch this tutorial to learn how to set up: https://help.github.com/en/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account
- [OPTIONAL] Install all packages and binaries following this [tutorial](REQUIREMENTS.md).

- Create a fork this repository.
- Clone the forked repository to your local system:

```bash
git clone FORKED_REPOSITORY
```

- Add the address for the remote original repository:

```bash
git remote -v
git remote add upstream git@github.com:aeciopires/learning-victoriametrics.git
git remote -v
```

- Configure your profile:

```bash
git config --local user.email "you@example.com"

git config --local user.name "Your Name"
```

- Create a branch. Example:

```bash
git checkout -b BRANCH_NAME
```

- Make sure you are on the correct branch using the following command. The branch in use contains the '*' before the name.

```bash
git branch
```

- Make your changes and tests to the new branch.

- Commit the changes to the branch.
- Push files to repository remote with command:

```bash
git push --set-upstream origin BRANCH_NAME
```

- Create Pull Request (PR) to the `main` branch. See this [tutorial](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork)
- Update the content with the suggestions of the reviewer (if necessary).
- After your pull request is merged to the `main` branch, update your local clone:

```bash
git checkout main
git pull upstream main
```

- Clean up after your pull request is merged with command:

```bash
git branch -d BRANCH_NAME
```

- Then you can update the ``main`` branch in your forked repository.

```bash
git push origin main
```

- And push the deletion of the feature branch to your GitHub repository with command:

```bash
git push --delete origin BRANCH_NAME
```

- To keep your fork in sync with the original repository, use these commands:

```bash
git pull upstream main
git push origin main
```

Reference:
- https://blog.scottlowe.org/2015/01/27/using-fork-branch-git-workflow/

# Testing and upgrading software versions

Every third-party component pinned in this repo (`kind` node image, MetalLB, ArgoCD, cert-manager, ingress-nginx, kube-prometheus-stack/Prometheus-Operator, and the VictoriaMetrics/VictoriaLogs/VictoriaTraces Helm charts) should be bumped and re-tested end-to-end on a local `kind-multinodes` cluster before opening a PR. Follow this sequence:

1. **Find the current pinned versions.**
   - `kind` node image: `KIND_CLUSTER_FILE` heredoc in [run.sh](run.sh) (`kindest/node:<tag>@sha256:<digest>`, repeated for each node).
   - `METALLB_CHART_VERSION`, `ARGOCD_CHART_VERSION`, `KUBE_PROMETHEUS_STACK_VERSION` (this last one is actually the Prometheus-Operator release tag used to fetch CRDs) at the top of [run.sh](run.sh).
   - `targetRevision` in each `helm-apps/<app>/application.yaml`.
   - Any explicit `image.tag` overrides inside `helm-apps/<app>/values.yaml` (e.g. `global.image.vm.tag` in [victoriametrics-cluster-mode/values.yaml](helm-apps/victoriametrics-cluster-mode/values.yaml), `common.image.tag` in [victorialogs-cluster-mode/values.yaml](helm-apps/victorialogs-cluster-mode/values.yaml)).
   - The chart image tag in [helm-apps/argocd/values.yaml](helm-apps/argocd/values.yaml) (`global.image.tag`).

2. **Look up the latest stable versions**, using the Helm repos already referenced by each `application.yaml`'s `repoURL`:

   ```bash
   helm repo add metallb https://metallb.github.io/metallb
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo add jetstack https://charts.jetstack.io
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo add victoriametrics https://victoriametrics.github.io/helm-charts/
   helm repo update
   helm search repo <repo>/<chart> --versions | head -5
   ```

   For the Prometheus-Operator CRDs applied directly in `run.sh` (not via Helm), match the `appVersion` reported for `prometheus-community/kube-prometheus-stack` — the chart bundles that exact Prometheus-Operator release, and its CRDs must match.

3. **Update every location found in step 1** consistently (`run.sh` vars, each `application.yaml`'s `targetRevision`, and any explicit `image.tag` in `values.yaml`). Update the "Bump software versions" list in [CHANGELOG.md](CHANGELOG.md) under a new version heading.

4. **Test on a local `kind-multinodes` cluster:**

   ```bash
   make down     # remove any existing kind-multinodes cluster
   make up       # recreate the cluster and reinstall/sync every app via ArgoCD
   ```

   `make up` requires `sudo` (it edits `/etc/hosts`) and can take 20-40+ minutes depending on image pull speed, since most Helm releases install with `--wait --timeout=900s` and ArgoCD apps must reach `Synced`/`Healthy`.

5. **Verify the cluster came up healthy** before opening a PR:

   ```bash
   kubectl get applications -n argocd                     # every Application should be Synced + Healthy
   kubectl get pods -A | grep -v Running                  # no CrashLoopBackOff/Pending/Error
   helm list -A                                            # every release should be "deployed"
   ```

   Then exercise each ingress URL documented in the relevant `helm-apps/<app>/README.md` (ArgoCD, Grafana, Prometheus, Alertmanager, vmui, kube-pires) to confirm logins and dashboards still work after the bump.

6. **Tear down** with `make down` once satisfied, so the branch isn't tied to local cluster state.

# Adding a new VictoriaMetrics-ecosystem Helm app (e.g. VictoriaTraces)

New components from the VictoriaMetrics Helm charts repository (https://github.com/VictoriaMetrics/helm-charts) follow the same recipe used for `victoriametrics-cluster-mode`, `victorialogs-cluster-mode` and `victoriatraces`:

1. Create `helm-apps/<new-app>/application.yaml`, copying an existing one (e.g. [helm-apps/victoriatraces/application.yaml](helm-apps/victoriatraces/application.yaml)) and adjusting `metadata.name`, `spec.destination.namespace`, `sources[0].chart` and `targetRevision`.
2. Generate a starting `values.yaml` from the chart's own defaults rather than writing one from scratch:

   ```bash
   helm repo add victoriametrics https://victoriametrics.github.io/helm-charts/
   helm repo update
   helm show values victoriametrics/<chart-name> --version <chart-version> > helm-apps/<new-app>/values.yaml
   ```

3. If the chart ships its own `vmauth`, keep it disabled (`vmauth.enabled: false`) and instead add `user-<app>-insert` / `user-<app>-select` entries to `vmauth.config.users` in [helm-apps/victoriametrics-cluster-mode/values.yaml](helm-apps/victoriametrics-cluster-mode/values.yaml), pointing at the new component's internal `*.monitoring.svc.cluster.local` DNS name. This repo intentionally exposes every VictoriaMetrics/VictoriaLogs/VictoriaTraces read/write path through the single shared vmauth ingress (`victoriametrics-cluster.mycompany.com`), differentiated by HTTP Basic Auth user, instead of one ingress hostname per component.
4. Set `nameOverride: ""` in the new `values.yaml` (rather than a chart-provided short name) so resource names follow the same `{release}-{chart}-{component}` pattern the vmauth `url_prefix` entries above depend on.
5. Add `kubectl -n argocd apply -f helm-apps/<new-app>/application.yaml` to [run.sh](run.sh), alongside the other `victoria*` apps.
6. Write `helm-apps/<new-app>/README.md` documenting the component architecture, the shared vmauth login, and internal write/read API DNS names/ports — follow the structure of [helm-apps/victoriatraces/README.md](helm-apps/victoriatraces/README.md).
7. Update the root [README.md](README.md) TOC/app list and [CLAUDE.md](CLAUDE.md), then run through the "Testing and upgrading software versions" steps above to validate the new app installs cleanly on `kind-multinodes`.
