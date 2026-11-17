<!-- TOC -->

- [MacOS](#macos)
  - [Homebrew](#homebrew)
  - [Essentials](#essentials)
- [Colima, docker and docker-compose](#colima-docker-and-docker-compose)
  - [inotify limits](#inotify-limits)
  - [Network](#network)
- [mise](#mise)
  - [Tools installed by mise](#tools-installed-by-mise)
  - [Helm plugins](#helm-plugins)
- [kind](#kind)

<!-- TOC -->

# MacOS

## Homebrew

Install Homebrew with the following command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "/Users/$USER/.bash_profile"

eval "$(/opt/homebrew/bin/brew shellenv)"
```

Reference: https://brew.sh/

## Essentials

Run the following commands:

```bash
software --install rosetta --agree-to-license

brew install vim telnet netcat git elinks curl wget net-tools python3 openjdk make coreutils gnupg bash visual-studio-code

echo 'export PATH="/opt/homebrew/opt/curl/bin:\$PATH"' >> "/User/$USER/.bash_profile"

export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
export CPPFLAGS="-I/opt/homebrew/opt/curl/include"

sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk

echo 'export PATH="/opt/homebrew/opt/openjdk/bin:\$PATH"' >> "/User/$USER/.bash_profile"

export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

echo 'export PATH="/opt/homebrew/opt/make/libexec/gnubin:\$PATH"' >> "/User/$USER/.bash_profile"

export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"

alias python=python3
alias pip=pip3
```

Install python3-pip following the instructions on the page: https://docs.brew.sh/Homebrew-and-Python

Install the following software:

- Google Chrome: https://support.google.com/chrome/answer/95346?hl=pt-BR&co=GENIE.Platform%3DDesktop#zippy=%2Cmac
  - Plugins for Visual Code
  - Instructions to export/import plugins: https://stackoverflow.com/questions/35773299/how-can-you-export-the-visual-studio-code-extension-list
  - docker: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker (Requires installation of the docker command shown in the following sections).
  - gitlens: https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens (Requires installation of the git command shown in the previous section).
  - Helm Intellisense: https://marketplace.visualstudio.com/items?itemName=Tim-Koehler.helm-intellisense
  - Markdown-all-in-one: https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one
  - Markdown-lint: https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint
  - Markdown-toc: https://marketplace.visualstudio.com/items?itemName=CharlesWan.markdown-toc
  - YAML: https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml
  - Theme for VSCode:
    - https://code.visualstudio.com/docs/getstarted/themes
    - https://dev.to/thegeoffstevens/50-vs-code-themes-for-2020-45cc
    - https://vscodethemes.com/

# Colima, docker and docker-compose

[Colima](https://github.com/abiosoft/colima) runs the container runtime in a lightweight Linux VM, used instead of Docker Desktop. Colima, the ``docker`` CLI and ``docker-compose`` are installed with Homebrew, outside of mise.

> Before proceeding, make sure you have installed the command [Homebrew](#homebrew).

```bash
brew install colima docker docker-compose

# Make "docker compose" (plugin syntax) find the docker-compose installed by Homebrew
mkdir -p ~/.docker/cli-plugins
ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" ~/.docker/cli-plugins/docker-compose
```

Start the Colima VM. The kind cluster of this lab (3 nodes, VictoriaMetrics, VictoriaLogs, VictoriaTraces, kube-prometheus-stack, ArgoCD, ...) used about 6 GB of memory in tests on Linux, so give the VM at least 4 CPUs and 12 GB of memory:

```bash
colima start --cpu 4 --memory 12 --disk 60

docker version
docker compose version
```

To start Colima automatically on login, run ``brew services start colima``.

References:
- https://github.com/abiosoft/colima
- https://github.com/abiosoft/colima/blob/main/docs/FAQ.md
- https://kind.sigs.k8s.io/docs/user/known-issues/

## inotify limits

The kind nodes share the inotify limits of the kernel of the Colima VM. If they are too low, pods like Vector (VictoriaLogs) crash with ``Too many open files``. ``run.sh`` only adjusts the limits of a Linux host, so on MacOS raise them inside the VM (it lasts until the VM restarts):

```bash
colima ssh -- sudo sysctl -w fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512
```

To apply it on every start, run ``colima start --edit`` and add a provision script to the configuration:

```yaml
provision:
  - mode: system
    script: sysctl -w fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512
```

Reference: https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files

## Network

``run.sh`` adds the address of the Envoy Gateway (a MetalLB IP of the ``kind`` docker network) to ``/etc/hosts``. On MacOS, this network is inside the Colima VM, so the IP may not be reachable from the host. In this case, forward the HTTPS port of the Gateway to your machine and point the hostnames to ``127.0.0.1``:

```bash
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=mycompany-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl -n envoy-gateway-system port-forward "svc/$SVC" 8443:443
```

Then, in ``/etc/hosts``, replace the Gateway IP by ``127.0.0.1`` and access the URLs with the port ``8443`` (example: https://grafana.mycompany.com:8443).

# mise

[mise](https://mise.jdx.dev) installs and pins the versions of every CLI used by this repository. The versions are declared in the [mise.toml](mise.toml) file at the root of the repository, and ``make`` runs every command through ``mise exec``, so the versions installed in your ``PATH`` don't matter.

> Before proceeding, make sure you have installed the command [Homebrew](#homebrew).

Install mise and activate it in your shell (zsh is the default shell of MacOS):

```bash
brew install mise

echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc

mise --version
```

> If you use bash, run ``echo 'eval "$(mise activate bash)"' >> ~/.bash_profile`` instead.

To update mise later, run ``brew upgrade mise``.

References:
- https://mise.jdx.dev/getting-started.html
- https://mise.jdx.dev/installing-mise.html

## Tools installed by mise

Inside the directory of this repository, install the tools declared in [mise.toml](mise.toml) (``make up`` also does it):

```bash
cd learning-victoriametrics
mise install
mise ls --current
```

| Tool | Description | Reference |
|---|---|---|
| ``argocd`` | ArgoCD CLI | https://argo-cd.readthedocs.io/en/stable/ |
| ``cmctl`` | cert-manager CLI, used by ``run.sh`` to wait for the cert-manager API | https://cert-manager.io/docs/reference/cmctl/ |
| ``helm`` | **Helm 4**. Helm 3 is not supported: ``make`` and ``run.sh`` fail if ``helm`` isn't version 4 | https://helm.sh/docs/overview/ |
| ``jq`` | JSON processor | https://jqlang.org/ |
| ``kind`` | Kubernetes in Docker, creates the local cluster | https://kind.sigs.k8s.io/ |
| ``kubectl`` | Kubernetes CLI | https://kubernetes.io/docs/reference/kubectl/ |

Every tool uses the [aqua backend](https://mise.jdx.dev/dev-tools/backends/aqua.html) of mise (official release binaries, verified with checksums). To bump a version, change it in [mise.toml](mise.toml) and run ``mise install``.

## Helm plugins

Optional. The ``helm-diff`` and ``helm-secrets`` plugins are installed by a [mise task](https://mise.jdx.dev/tasks/) declared in [mise.toml](mise.toml):

```bash
make helm-plugins
# or
mise run helm-plugins
```

Helm 4 verifies plugin provenance by default and doesn't support ``--version`` for plugins anymore, so the task installs the signed release tarballs, verifying them with the GPG public keys of the maintainers. In Helm 4, ``helm-secrets`` is split into three plugins: ``secrets``, ``secrets-getter`` and ``secrets-post-renderer``.

References:
- https://github.com/databus23/helm-diff
- https://github.com/jkroepke/helm-secrets/blob/main/docs/Installation.md

# kind

Kind (Kubernetes in Docker) runs Kubernetes in a local environment for testing and learning, but it is not recommended for production use. It's installed by mise (see [Tools installed by mise](#tools-installed-by-mise)) and uses the docker of Colima.

The cluster of this lab (``kind-multinodes``, 1 control plane and 2 workers) is created by ``make up``, with the configuration written by [run.sh](run.sh) (``KIND_CLUSTER_FILE``).

Useful commands:

```bash
kind get clusters
kind get nodes --name kind-multinodes
```

References:
- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://github.com/kubernetes-sigs/kind/releases
