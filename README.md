# Prometheus Monitoring Mixin for Flux V2

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Requirements

### jsonnet

`Flux-mixin` use `jsonnet`

We recommend to use [go-jsonnet](https://github.com/google/go-jsonnet). It's an implementation of [Jsonnet](http://jsonnet.org/) in pure Go. It is feature complete but is not as heavily exercised as the [Jsonnet C++ implementation](https://github.com/google/jsonnet).

To install:

```shell
go get github.com/google/go-jsonnet/cmd/jsonnet
```

### jsonnet-bundler

`Flux-mixin` uses [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler#install) (the jsonnet package manager) to manage its dependencies.

We recommended you to use `jsonnet-bundler` to install or update if you decide to use `flux-mixin` as a dependency for your custom mixins.

```
go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
```

## Multi-cluster support

Flux-mixin can support dashboards across multiple clusters. You need either a multi-cluster [Thanos](https://github.com/improbable-eng/thanos) installation with `external_labels` configured or a [Cortex](https://github.com/cortexproject/cortex) system where a cluster label exists. To enable this feature you need to configure the following:

```
    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: true,
    clusterLabel: '<your cluster label>',
```

## Generate flux alerts and dashboards

Alerts and dashboards will be generated to `files/` directory using:

```shell
jb install

make alerts
make dashboards
```

## Use as a library

To use the `flux-mixin` as a dependency, simply use the `jsonnet-bundler` to install:

```shell
$ mkdir custom-mixin; cd custom-mixin
$ jb init # Create/Initial empty `jsonnetfile.json` for dependency management
# Install flux-mixin dependency
$ jb install github.com/fluxcd-community/flux-mixin
```

in a directory, add a file `mixin.libsonnet`:

```libsonnet
local flux = import "github.com/fluxcd-community/flux-mixin/mixin.libsonnet"; // import full path to avoid collusion with other mixin

flux {
  _config+:: {
    showMultiCluster: true,
    clusterLabel: 'cluster',
  },
}
```

Then generate the alerts and dashboards

```shell
$ mkdir -p files/dashboards 
$ jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts)' > flies/alerts.yml
$ jsonnet -J vendor -m files/dashboards -e '(import "mixin.libsonnet").grafanaDashboards'
```
