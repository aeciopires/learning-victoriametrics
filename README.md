<!-- TOC -->

- [About](#about)
- [Use Case](#use-case)
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

# About



# Use Case

[VictoriaMetrics](https://victoriametrics.com) is a fast, cost-effective and scalable time series database. It can be used as a long-term remote storage for [Prometheus](https://prometheus.io/).

I worked at Sensedia for almost 5 years and used VIctoriaMetrics in production collecting metrics from over 100 clusters (EKS and GKE) running hundreds of pods on each cluster and going through 5 Black Friday without downtime in the monitoring stack.

Details of this use case can be found in the following links:

- [en-US] https://victoriametrics.com/case-studies/sensedia/ 
- [en-US] https://docs.victoriametrics.com/casestudies/#sensedia 
- [en-US] https://nordicapis.com/api-monitoring-with-prometheus-grafana-alertmanager-and-victoriametrics/ 
- [es] https://www.sensedia.com.es/post/seguimiento-con-prometheus-grafana-alertmanager-and-victoriametrics 
- [pt-BR] https://www.sensedia.com.br/post/monitoramento-de-aplicacoes-com-prometheus-grafana-alertmanager-e-victoriametrics
- [pt-BR] https://speakerdeck.com/aeciopires/monitoramento-de-aplicacoes-com-prometheus-grafana-alertmanager-e-victoriametrics 
- Slides (pt-BR): https://speakerdeck.com/aeciopires/monitoramento-de-aplicacoes-com-prometheus-grafana-alertmanager-e-victoriametrics 

I also contribute to the VictoriaMetrics helm chart:

- https://github.com/VictoriaMetrics/helm-charts 
- https://github.com/VictoriaMetrics/helm-charts/graphs/contributors

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
