<!-- TOC -->

- [MacOS](#macos)
  - [Homebrew](#homebrew)
  - [Essentials](#essentials)
- [asdf](#asdf)
- [argocd-cli](#argocd-cli)
- [docker](#docker)
- [Go](#go)
- [cmctl](#cmctl)
- [Helm](#helm)
- [helm-diff - Plugin](#helm-diff---plugin)
- [helm-secrets - Plugin](#helm-secrets---plugin)
- [kubectl](#kubectl)
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

brew install vim telnet netcat git elinks curl wget net-tools python3 openjdk jq make coreutils visual-studio-code

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

# asdf

Run the following commands:

> Attention!!! To update ``asdf``, ONLY use the following command:

```bash
asdf update
```

> If you try to reinstall or update by changing the version in the following commands, you will need to reinstall all plugins/commands installed before, so it is very important to back up the ``$HOME/.asdf`` directory.

```bash
ASDF_VERSION="v0.15.0"
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch $ASDF_VERSION

# Adding $HOME/.bashrc
echo ". \"\$HOME/.asdf/asdf.sh\"" >> ~/.bash_profile
echo ". \"\$HOME/.asdf/completions/asdf.bash\"" >> ~/.bash_profile
source ~/.bash_profile
```

Reference: https://asdf-vm.com/guide/introduction.html

# argocd-cli

Install ``argocd-cli`` using ``asdf``:

> Before proceeding, make sure you have installed the command [asdf](#asdf).

```bash
VERSION=3.0.0
asdf plugin-add argocd https://github.com/beardix/asdf-argocd.git
asdf list all argocd
asdf install argocd $VERSION
asdf global argocd $VERSION
```

References:
- https://argo-cd.readthedocs.io/en/stable/
- https://github.com/beardix/asdf-argocd
- http://blog.aeciopires.com/usando-o-argo-cd-para-implementar-a-abordagem-gitops-nos-clusters-kubernetes/

# docker

Install Docker CE (Community Edition) following the instructions on the page: https://docs.docker.com/desktop/install/mac-install/.

Run the following commands:

> Before proceeding, make sure you have installed the command [Homebrew](#homebrew).

```bash
brew install --cask docker
brew install docker-machine
```

Reference: https://stackoverflow.com/questions/44084846/cannot-connect-to-the-docker-daemon-on-macos

# Go

Run the following commands to install Go.

> Before proceeding, make sure you have installed the command [Homebrew](#homebrew).

```bash
brew install go
```

Reference: https://golang.org/doc/

# cmctl

``cmctl`` is a CLI tool that can help you to manage cert-manager resources inside your cluster.

Run the following commands to install cmctl:

> Before proceeding, make sure you have installed the command [go](#go).

```bash
OS=$(go env GOOS); ARCH=$(go env GOARCH); curl -sSL -o cmctl.tar.gz https://github.com/cert-manager/cert-manager/releases/download/v1.7.2/cmctl-$OS-$ARCH.tar.gz
tar xzf cmctl.tar.gz
sudo mv cmctl /usr/local/bin
rm cmctl.tar.gz
```

Reference: https://cert-manager.io/v1.7-docs/usage/cmctl/#installation

# Helm

Run the following commands to install helm:

> Before proceeding, make sure you have installed the command [asdf](#asdf).

Reference: https://helm.sh/docs/

```bash
VERSION="3.17.3"

asdf plugin list all | grep helm
asdf plugin add helm https://github.com/Antiarchitect/asdf-helm.git
asdf latest helm

asdf install helm $VERSION
asdf list helm

asdf global helm $VERSION
asdf list helm
```

# helm-diff - Plugin

Run the following commands to install the ``helm-diff`` plugin.

Reference: https://github.com/databus23/helm-diff

```bash
helm plugin install https://github.com/databus23/helm-diff --version v3.11.0
```

# helm-secrets - Plugin

Run the following commands to install the ``helm-secrets`` plugin.

Reference: https://github.com/jkroepke/helm-secrets

```bash
helm plugin install https://github.com/jkroepke/helm-secrets --version v4.6.3
```

# kubectl

Run the following commands.

Reference: https://kubernetes.io/docs/reference/kubectl/overview/

```bash
VERSION_OPTION_1="1.33.0"

asdf plugin list all | grep kubectl
asdf plugin add kubectl https://github.com/asdf-community/asdf-kubectl.git
asdf latest kubectl

asdf install kubectl $VERSION_OPTION_1
asdf list kubectl

asdf global kubectl $VERSION_OPTION_1
asdf list kubectl

sudo ln -s $HOME/.asdf/shims/kubectl /usr/local/bin/kubectl
```

# kind

Kind (Kubernetes in Docker) is another alternative for running Kubernetes in a local environment for testing and learning, but it is not recommended for production use.

To install kind, run the following commands.

> Before proceeding, make sure you have installed the command [asdf](#asdf).

```bash
VERSION="0.27.0"
asdf plugin list all | grep kind
asdf plugin add kind https://github.com/johnlayton/asdf-kind.git
asdf latest kind
asdf install kind $VERSION
asdf list kind

asdf global kind $VERSION
```

To create a multi-node cluster with Kind, create a YAML file to define the number and type of nodes in the cluster that you want.

In the following example, you will create the file ``$HOME/kind-3nodes.yaml`` to specify a cluster with 1 master node (which will run the Kubernetes control plane) and 2 workers (which will run the Kubernetes data plane).

```bash
cat << EOF > $HOME/kind-3nodes.yaml
# References:
# Kind release image: https://github.com/kubernetes-sigs/kind/releases
# Configuration: https://kind.sigs.k8s.io/docs/user/configuration/
# Metal LB in Kind: https://kind.sigs.k8s.io/docs/user/loadbalancer
# Ingress in Kind: https://kind.sigs.k8s.io/docs/user/ingress

# Config compatible with kind v0.27.0
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
  - role: control-plane
    image: kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "nodeapp=loadbalancer"
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      listenAddress: "0.0.0.0" # Optional, defaults to "0.0.0.0"
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      listenAddress: "0.0.0.0" # Optional, defaults to "0.0.0.0"
      protocol: TCP
  - role: worker
    image: kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f
  - role: worker
    image: kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f
EOF
```

Create a cluster named ``kind-multinodes`` using the specifications defined in the ``$HOME/kind-3nodes.yaml`` file.

```bash
kind create cluster --name kind-multinodes --config $HOME/kind-3nodes.yaml
```

To view your clusters using kind, run the following command.

```bash
kind get clusters
```

To destroy the cluster, run the following command which will select and remove all local clusters created on Kind.

```bash
kind delete clusters $(kind get clusters)
```

References:
- https://github.com/badtuxx/DescomplicandoKubernetes/blob/master/day-1/DescomplicandoKubernetes-Day1.md#kind
- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://github.com/kubernetes-sigs/kind/releases
- https://kubernetes.io/blog/2020/05/21/wsl-docker-kubernetes-on-the-windows-desktop/#kind-kubernetes-made-easy-in-a-container
