# install-victoria-metrics-cluster-mode

<!-- TOC -->

- [install-victoria-metrics-cluster-mode](#install-victoria-metrics-cluster-mode)
- [Requirements](#requirements)
  - [vmauth](#vmauth)
- [Troubleshooting](#troubleshooting)
- [Write API](#write-api)
  - [Read API](#read-api)
- [References](#references)

<!-- TOC -->

# Requirements

- Install all packages and binaries following the instructions on the [REQUIREMENTS.md](../../REQUIREMENTS.md) file.
- Create the cluster following the instructions on the [README.md](../../README.md#create-the-cluster-and-deploy-applications) file.

## vmauth

**vmauth** is an HTTP proxy, which can authorize, route and load balance 
requests across VictoriaMetrics components or any other HTTP backends.
Reference: https://docs.victoriametrics.com/victoriametrics/vmauth/

# Troubleshooting

Get the pods lists by running these commands:

```bash
kubectl get all -n monitoring | grep 'victoria\|vmauth'
```

# Write API

``Outside`` cluster:

> **NOTE:** But outside cluster the service is accessed in external URL.

You need to update your prometheus configuration file and add next lines into it:

**prometheus.yml**

External URL for Prometheus sending data to Victoria Metrics:

```yaml
CHANGE_HERE
```

## Read API

> **NOTE:** But outside cluster the service is accessed in external URL.

You need to update specify select service URL in your Grafana:

> NOTE: you need to use Prometheus Data Source

External URL for datasource in Grafana installed outside cluster:

```
CHANGE_HERE
```

# References

See [../../LEARNING_VICTORIAMETRICS.md](../../LEARNING_VICTORIAMETRICS.md) file.
