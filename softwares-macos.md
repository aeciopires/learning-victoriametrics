<!-- TOC -->

- [MacOS](#macos)
  - [Homebrew](#homebrew)
  - [Essentials](#essentials)
  - [Optionals](#optionals)
- [Colima, docker and docker-compose](#colima-docker-and-docker-compose)
  - [inotify limits](#inotify-limits)
  - [Network](#network)
- [mise](#mise)

<!-- TOC -->

Specific instructions for MacOS. What is common to every operating system (tools installed by mise, Helm plugins, kind, optional VSCode plugins) is in [REQUIREMENTS.md](REQUIREMENTS.md).

# MacOS

## Homebrew

Install Homebrew with the following command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.bash_profile

eval "$(/opt/homebrew/bin/brew shellenv)"
```

Reference: https://brew.sh/

## Essentials

> Before proceeding, make sure you have installed the command [Homebrew](#homebrew).

Run the following commands:

```bash
softwareupdate --install-rosetta --agree-to-license

brew install vim telnet netcat git elinks curl wget net-tools python3 openjdk make coreutils gnupg bash

echo 'export PATH="/opt/homebrew/opt/curl/bin:$PATH"' >> ~/.bash_profile

export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
export CPPFLAGS="-I/opt/homebrew/opt/curl/include"

sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk

echo 'export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"' >> ~/.bash_profile

export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

echo 'export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"' >> ~/.bash_profile

export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"

alias python=python3
alias pip=pip3
```

Install python3-pip following the instructions on the page: https://docs.brew.sh/Homebrew-and-Python

## Optionals

See the list of optional software and VSCode plugins in [REQUIREMENTS.md](REQUIREMENTS.md#optionals). On MacOS:

- Google Chrome: https://support.google.com/chrome/answer/95346?hl=pt-BR&co=GENIE.Platform%3DDesktop#zippy=%2Cmac
- Visual Studio Code: ``brew install --cask visual-studio-code``

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

See why in [REQUIREMENTS.md](REQUIREMENTS.md#inotify-limits). On MacOS, the limits that matter are the ones of the kernel of the Colima VM, and ``run.sh`` doesn't change them. Raise them inside the VM (it lasts until the VM restarts):

```bash
colima ssh -- sudo sysctl -w fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512
```

To apply it on every start, run ``colima start --edit`` and add a provision script to the configuration:

```yaml
provision:
  - mode: system
    script: sysctl -w fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512
```

## Network

``run.sh`` adds the address of the Envoy Gateway (a MetalLB IP of the ``kind`` docker network) to ``/etc/hosts``. On MacOS, this network is inside the Colima VM, so the IP may not be reachable from the host. In this case, forward the HTTPS port of the Gateway to your machine and point the hostnames to ``127.0.0.1``:

```bash
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=mycompany-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl -n envoy-gateway-system port-forward "svc/$SVC" 8443:443
```

Then, in ``/etc/hosts``, replace the Gateway IP by ``127.0.0.1`` and access the URLs with the port ``8443`` (example: https://grafana.mycompany.com:8443).

# mise

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

Then install the tools of this repository: see [Tools installed by mise](REQUIREMENTS.md#tools-installed-by-mise).
