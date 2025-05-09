<!-- TOC -->

- [Contributing](#contributing)
- [VictoriaMetrics documentation](#victoriametrics-documentation)
- [Requirements](#requirements)
- [Create cluster and deploy applications](#create-cluster-and-deploy-applications)
  - [VictoriaMetrics Cluster Mode](#victoriametrics-cluster-mode)
  - [argocd](#argocd)
  - [ingress-nginx](#ingress-nginx)
  - [cert-manager](#cert-manager)
  - [kube-prometheus-stack](#kube-prometheus-stack)
  - [kube-pires](#kube-pires)
- [Tools used](#tools-used)
- [Request workflow](#request-workflow)
- [Uninstall](#uninstall)
- [Maintainers](#maintainers)
- [License](#license)

<!-- TOC -->

# Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) file.

# VictoriaMetrics documentation

See [LEARNING_VICTORIAMETRICS.md](LEARNING_VICTORIAMETRICS.md) file.

# Requirements

Install all packages and binaries following this [tutorial](REQUIREMENTS.md).

# Create cluster and deploy applications

Create kind cluster and install helm apps using ``make`` command:

```bash
cd learning-victoriametrics
make up
```

Actions performed:

- Check requirements
- Create kind Kubernetes cluster
- Install helm apps: MetalLB, VictoriaMetrics (cluster mode), ingress-nginx, certificate-manager, kube-pires and kube-stack-prometheus
- Insert new entry in /etc/hosts (Linux/MacOS)

## VictoriaMetrics Cluster Mode

See the [helm-apps/victoriametrics-cluster-mode/README.md](helm-apps/victoriametrics-cluster-mode/README.md) file to configure VictoriaMetrics cluster mode.

## argocd

See the [helm-apps/argocd/README.md](helm-apps/argocd/README.md)

## ingress-nginx

See the [helm-apps/ingress-nginx/README.md](helm-apps/ingress-nginx/README.md)

## cert-manager

See the [helm-apps/cert-manager/README.md](helm-apps/cert-manager/README.md)

## kube-prometheus-stack

See the [helm-apps/kube-stack-prometheus/README.md](helm-apps/kube-prometheus-stack/README.md)

## kube-pires

See the [helm-apps/kube-pires/README.md](helm-apps/kube-pires/README.md)

# Tools used

![tools-used](images/tools-used.png)

# Request workflow

![request-workflow](images/request-workflow.png)

# Uninstall

Destroy Kind cluster and uninstall apps:

```bash
cd learning-victoriametrics
make down
```

# Maintainers

- Aécio dos Santos Pires ([linkedin.com/in/aeciopires](https://www.linkedin.com/in/aeciopires/?locale=en_US))

# License

GPL-3.0 Aécio dos Santos Pires
