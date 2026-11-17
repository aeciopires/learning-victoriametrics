<!-- TOC -->

- [Requirements](#requirements)
  - [Supported operating systems](#supported-operating-systems)
  - [Installed outside of mise](#installed-outside-of-mise)
  - [mise](#mise)
    - [Tools installed by mise](#tools-installed-by-mise)
    - [Helm plugins](#helm-plugins)
  - [kind](#kind)
    - [inotify limits](#inotify-limits)
  - [Optionals](#optionals)
  - [Checking the requirements](#checking-the-requirements)

<!-- TOC -->

# Requirements

This page describes what is common to every supported operating system. The steps that are specific to each one are in its own page.

## Supported operating systems

| Operating system | Specific instructions |
|---|---|
| **Ubuntu** 26.04, 24.04 or 22.04 LTS (64 bits) | [softwares-ubuntu.md](softwares-ubuntu.md) |
| **MacOS** (with Homebrew and Colima) | [softwares-macos.md](softwares-macos.md) |

Follow the page of your operating system first, then come back to this page.

## Installed outside of mise

| Software | Ubuntu | MacOS |
|---|---|---|
| Essential packages (``make``, ``curl``, ``gpg``, ``git``, ...) | ``apt`` | Homebrew |
| Container runtime | Docker CE + ``docker compose`` plugin (or ``docker.io`` + ``docker-compose-v2`` from the Ubuntu archive) | Colima + ``docker`` CLI + ``docker-compose`` (Homebrew) |
| [mise](https://mise.jdx.dev) | ``curl https://mise.run \| sh`` | ``brew install mise`` |
| ``sudo`` | Installed by default (sudo-rs on 26.04) | Installed by default |

## mise

[mise](https://mise.jdx.dev) installs and pins the versions of every CLI used by this repository. The versions are declared in the [mise.toml](mise.toml) file at the root of the repository, and ``make`` runs every command through ``mise exec``, so the versions installed in your ``PATH`` don't matter.

The installation of mise itself and its activation in the shell depend on the operating system: see [Ubuntu](softwares-ubuntu.md#mise) or [MacOS](softwares-macos.md#mise).

References:
- https://mise.jdx.dev/getting-started.html
- https://mise.jdx.dev/installing-mise.html

### Tools installed by mise

Inside the directory of this repository, install the tools declared in [mise.toml](mise.toml) (``make up`` also does it):

```bash
cd learning-victoriametrics
mise install
mise ls --current
```

| Tool | Version | Description | Reference |
|---|---|---|---|
| ``argocd`` | 3.6.1 | ArgoCD CLI | https://argo-cd.readthedocs.io/en/stable/ |
| ``cmctl`` | 2.6.2 | cert-manager CLI, used by ``run.sh`` to wait for the cert-manager API | https://cert-manager.io/docs/reference/cmctl/ |
| ``helm`` | 4.3.2 | **Helm 4**. Helm 3 is not supported: ``make`` and ``run.sh`` fail if ``helm`` isn't version 4 | https://helm.sh/docs/overview/ |
| ``jq`` | 1.8.2 | JSON processor | https://jqlang.org/ |
| ``kind`` | 0.33.0 | Kubernetes in Docker, creates the local cluster | https://kind.sigs.k8s.io/ |
| ``kubectl`` | 1.37.2 | Kubernetes CLI | https://kubernetes.io/docs/reference/kubectl/ |

Every tool uses the [aqua backend](https://mise.jdx.dev/dev-tools/backends/aqua.html) of mise (official release binaries, verified with checksums). To bump a version, change it in [mise.toml](mise.toml) (and in the table above) and run ``mise install``.

When mise is activated in your shell, these versions are used automatically inside the directory of the repository. Outside of it, run ``mise exec -- <command>`` from the repository directory, or use ``make``.

### Helm plugins

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

## kind

Kind (Kubernetes in Docker) runs Kubernetes in a local environment for testing and learning, but it is not recommended for production use. It's installed by mise (see [Tools installed by mise](#tools-installed-by-mise)) and uses the docker of the host (Ubuntu) or of the Colima VM (MacOS).

The cluster of this lab (``kind-multinodes``, 1 control plane and 2 workers) is created by ``make up``, with the configuration written by [run.sh](run.sh) (``KIND_CLUSTER_FILE``). It used about 6 GB of memory in tests.

Useful commands:

```bash
kind get clusters
kind get nodes --name kind-multinodes
```

References:
- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://github.com/kubernetes-sigs/kind/releases

### inotify limits

The kind nodes share the inotify limits of the Linux kernel where docker runs (the host on Ubuntu, the Colima VM on MacOS). With low limits (e.g. ``max_user_instances=128``, the Ubuntu default), pods like Vector (VictoriaLogs) crash with ``Too many open files``. kind recommends at least:

```
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
```

On Linux, ``run.sh`` raises the limits with ``sudo sysctl -w`` when they are too low, but only until the next reboot. How to make it permanent: [Ubuntu](softwares-ubuntu.md#inotify-limits) or [MacOS (Colima VM)](softwares-macos.md#inotify-limits).

Reference: https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files

## Optionals

Not required by this repository, but useful:

- Google Chrome
- Visual Studio Code: https://code.visualstudio.com (see the page of your operating system for the installation)
  - Plugins for Visual Code
  - Instructions to export/import plugins: https://stackoverflow.com/questions/35773299/how-can-you-export-the-visual-studio-code-extension-list
  - docker: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker
  - gitlens: https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens
  - Helm Intellisense: https://marketplace.visualstudio.com/items?itemName=Tim-Koehler.helm-intellisense
  - Markdown-all-in-one: https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one
  - Markdown-lint: https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint
  - Markdown-toc: https://marketplace.visualstudio.com/items?itemName=CharlesWan.markdown-toc
  - YAML: https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml
  - Theme for VSCode:
    - https://code.visualstudio.com/docs/getstarted/themes
    - https://dev.to/thegeoffstevens/50-vs-code-themes-for-2020-45cc
    - https://vscodethemes.com/

## Checking the requirements

Run ``make requirements`` to check the softwares installed outside of mise (``mise``, ``docker`` running, ``curl``, ``gpg``, ``sudo``), install the tools of [mise.toml](mise.toml) and check that ``helm`` is version 4. On Ubuntu, it also prints a warning if the release isn't one of the supported versions.
