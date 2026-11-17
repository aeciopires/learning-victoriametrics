<!-- TOC -->

- [Ubuntu](#ubuntu)
  - [Essential](#essential)
  - [Optionals](#optionals)
- [docker](#docker)
- [mise](#mise)
  - [Tools installed by mise](#tools-installed-by-mise)
  - [Helm plugins](#helm-plugins)
- [kind](#kind)
  - [inotify limits](#inotify-limits)

<!-- TOC -->

# Ubuntu

## Essential

Run the following commands on Ubuntu 24.04/22.02:

```bash
sudo apt install -y vim telnet netcat-openbsd git elinks curl wget net-tools python3 python3-pip python3-venv default-jdk make gnupg
```

For Python "3.10.*" run the following command to create the symbolic link:

```bash
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
```

For Python "3.12.*" run the following command to create the symbolic link:

```bash
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1
```

## Optionals

Install the following software:

- Google Chrome
- Visual Code: https://code.visualstudio.com
  - Ubuntu install: https://code.visualstudio.com/docs/setup/linux
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

# docker

Docker and Docker Compose are installed outside of mise. Install Docker CE (Community Edition) following the instructions on the page: <https://docs.docker.com/engine/install/ubuntu/>. The convenience script also installs the ``docker compose`` plugin.

```bash
sudo apt update
sudo apt install -y acl
curl -fsSL https://get.docker.com -o get-docker.sh;
sudo sh get-docker.sh;
sudo usermod -aG docker $USER;
sudo setfacl -m user:$USER:rw /var/run/docker.sock

docker version
docker compose version
```

Reference: <https://docs.docker.com/engine/install/linux-postinstall/#configure-docker-to-start-on-boot>

# mise

[mise](https://mise.jdx.dev) installs and pins the versions of every CLI used by this repository. The versions are declared in the [mise.toml](mise.toml) file at the root of the repository, and ``make`` runs every command through ``mise exec``, so the versions installed in your ``PATH`` don't matter.

Install mise and activate it in your shell:

```bash
curl https://mise.run | sh

echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

mise --version
```

> If you use zsh, run ``echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc`` instead.

To update mise later, run:

```bash
mise self-update
```

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

When mise is activated in your shell, these versions are used automatically inside the directory of the repository. Outside of it, run ``mise exec -- <command>`` from the repository directory, or use ``make``.

## Helm plugins

Optional. The ``helm-diff`` and ``helm-secrets`` plugins are installed by a [mise task](https://mise.jdx.dev/tasks/) declared in [mise.toml](mise.toml):

```bash
make helm-plugins
# or
mise run helm-plugins
```

Helm 4 verifies plugin provenance by default and doesn't support ``--version`` for plugins anymore, so the task installs the signed release tarballs, verifying them with the GPG public keys of the maintainers (https://github.com/databus23.gpg and https://github.com/jkroepke.gpg). In Helm 4, ``helm-secrets`` is split into three plugins: ``secrets``, ``secrets-getter`` and ``secrets-post-renderer``. The task is idempotent: it only installs the plugins missing or in another version.

References:
- https://github.com/databus23/helm-diff
- https://github.com/jkroepke/helm-secrets/blob/main/docs/Installation.md

# kind

Kind (Kubernetes in Docker) runs Kubernetes in a local environment for testing and learning, but it is not recommended for production use. It's installed by mise (see [Tools installed by mise](#tools-installed-by-mise)).

The cluster of this lab (``kind-multinodes``, 1 control plane and 2 workers) is created by ``make up``, with the configuration written by [run.sh](run.sh) (``KIND_CLUSTER_FILE``).

Useful commands:

```bash
kind get clusters
kind get nodes --name kind-multinodes
```

References:
- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://github.com/kubernetes-sigs/kind/releases

## inotify limits

The kind nodes share the inotify limits of the host kernel. The Ubuntu defaults (``max_user_instances=128``) are too low for multi-node clusters, and pods like Vector (VictoriaLogs) crash with ``Too many open files``.

``run.sh`` raises the limits with ``sudo sysctl -w`` when they are too low, but only until the next reboot. To make the change permanent:

```bash
cat << EOF | sudo tee /etc/sysctl.d/99-kind-inotify.conf
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF

sudo sysctl --system
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances
```

Reference: https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files
