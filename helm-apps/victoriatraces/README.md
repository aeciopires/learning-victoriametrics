# install-victoria-traces-cluster-mode

<!-- TOC -->

- [install-victoria-traces-cluster-mode](#install-victoria-traces-cluster-mode)
- [Requirements](#requirements)
- [VictoriaTraces Cluster Mode](#victoriatraces-cluster-mode)
- [Architecture](#architecture)
  - [vmauth](#vmauth)
- [Troubleshooting](#troubleshooting)
- [Write API](#write-api)
  - [Read API](#read-api)
- [References](#references)

<!-- TOC -->

# Requirements

- Install all packages and binaries following the instructions on the [REQUIREMENTS.md](../../REQUIREMENTS.md) file.
- Create the cluster following the instructions on the [README.md](../../README.md#create-the-cluster-and-deploy-applications) file.

# VictoriaTraces Cluster Mode

> Reference: https://docs.victoriametrics.com/victoriatraces/

**VictoriaTraces** is an open-source, resource-efficient database for storing and querying distributed tracing data, built by the VictoriaMetrics team. It accepts trace spans via the OpenTelemetry protocol (OTLP) and the Jaeger protocol, and exposes Jaeger Query Service JSON APIs so it can be queried directly from Grafana or the Jaeger Frontend UI, without requiring an external object store or a database like ClickHouse or Elasticsearch.

# Architecture

VictoriaTraces in cluster mode consists of the following components:

- **vtinsert**: accepts incoming trace spans (OTLP and Jaeger) and spreads them evenly among the ``vtstorage`` nodes.
- **vtselect**: accepts incoming queries (Jaeger Query Service JSON API), requests the needed data from ``vtstorage`` nodes, processes the queries and returns the corresponding responses.
- **vtstorage**: stores the ingested trace spans at the directory specified via ``-storageDataPath`` command-line flag.

Every component can scale from a single node to arbitrary number of nodes and can run on the most suitable hardware for the given workload. This follows the same shared-nothing cluster architecture as [VictoriaMetrics](../victoriametrics-cluster-mode/README.md) and [VictoriaLogs](../victorialogs-cluster-mode/README.md).

## vmauth

Just like VictoriaLogs cluster mode, this chart's own ``vmauth`` (see ``vmauth.enabled`` in [values.yaml](values.yaml)) is disabled. Access is instead routed through the single ``vmauth`` deployed by [victoriametrics-cluster-mode](../victoriametrics-cluster-mode/README.md), which fronts all VictoriaMetrics/VictoriaLogs/VictoriaTraces components behind one ingress hostname and authorizes requests per-user via HTTP Basic Auth. See the ``vmauth.config.users`` entries in [../victoriametrics-cluster-mode/values.yaml](../victoriametrics-cluster-mode/values.yaml).

- URL: https://victoriametrics-cluster.mycompany.com/
- Write (insert) login: user-traces-insert / changeme
- Read (select) login: user-traces-select / changeme

# Troubleshooting

Get the pods lists by running these commands:

```bash
kubectl get all -n monitoring | grep 'victoria-traces\|vmauth'
```

# Write API

``Inside`` cluster:

``vtinsert`` accepts trace spans at the port **10481** on the following DNS name from within your cluster: **victoria-traces-victoria-traces-cluster-vtinsert.monitoring.svc.cluster.local**

> **NOTE:** But outside cluster the service is accessed via the shared vmauth ingress described above.

Internal URL to send OTLP/gRPC traces inside the cluster:

```
victoria-traces-victoria-traces-cluster-vtinsert.monitoring.svc.cluster.local:4317
```

> **NOTE:** The OTLP gRPC listener is disabled by default. See ``vtinsert.extraArgs`` in [values.yaml](values.yaml) and the [data ingestion docs](https://docs.victoriametrics.com/victoriatraces/data-ingestion/) to enable it and configure OTLP/HTTP or Jaeger ingestion instead.

## Read API

``vtselect`` accepts incoming queries at the port **10471** on the following DNS name from within your cluster: **victoria-traces-victoria-traces-cluster-vtselect.monitoring.svc.cluster.local**

> **NOTE:** But outside cluster the service is accessed via the shared vmauth ingress described above.

You need to configure a Jaeger data source in Grafana pointing to the Jaeger Query Service JSON API exposed by ``vtselect``. See [these docs](https://docs.victoriametrics.com/victoriatraces/#grafana) for details about visualizing traces in Grafana.

# References

See [../../LEARNING_VICTORIAMETRICS.md](../../LEARNING_VICTORIAMETRICS.md) file.
