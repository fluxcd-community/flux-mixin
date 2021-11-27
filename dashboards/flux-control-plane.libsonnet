local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

local dashboard = grafana.dashboard;
local gaugePanel = grafana.gaugePanel;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;
local row = grafana.row;
local statPanel = grafana.statPanel;
local template = grafana.template;

{
  grafanaDashboards+:: {
    'flux-control-plane.json':
      local controllers =
        statPanel.new(
          title='Controllers',
          datasource='$datasource',
          graphMode='none',
          reducerFunction='last',
        )
        .addTarget(
          prometheus.target(
            'sum(go_info{%(clusterLabel)s="$cluster",namespace="$namespace",pod=~".*-controller-.*"})' % $._config,
          )
        )
        .addThreshold({ color: 'blue', value: null })
        .addThreshold({ color: 'red', value: 100 });

      local maxWorkQueue =
        statPanel.new(
          title='Max Work Queue',
          datasource='$datasource',
          reducerFunction='lastNotNull',
          unit='s'
        )
        .addTarget(
          prometheus.target(
            'max(workqueue_longest_running_processor_seconds{%(clusterLabel)s="$cluster",namespace="$namespace",pod=~".*-controller-.*"})' % $._config,
            legendFormat='seconds',
            intervalFactor=1,
          )
        )
        .addThreshold({ color: 'blue', value: null })
        .addThreshold({ color: 'yellow', value: 50 })
        .addThreshold({ color: 'red', value: 100 });

      local memory =
        gaugePanel.new(
          title='Memory',
          datasource='$datasource',
          reducerFunction='lastNotNull',
          unit='decbits',
          min=null,
          max=null,
        )
        .addTarget(
          prometheus.target(
            'sum(go_memstats_alloc_bytes{%(clusterLabel)s="$cluster",namespace="$namespace",pod=~".*-controller-.*"})' % $._config,
          )
        )
        .addThreshold({ color: 'blue', value: null })
        .addThreshold({ color: 'yellow', value: 500000000 })  // 500Mb
        .addThreshold({ color: 'red', value: 900000000 });  // 900Mb

      local apiRequests =
        statPanel.new(
          title='API Requests',
          datasource='$datasource',
        )
        .addTarget(
          prometheus.target(
            'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",namespace="$namespace",pod=~".*-controller-.*"}[1m]))' % $._config,
            legendFormat='requests'
          )
        )
        .addThreshold({ color: 'blue', value: null })
        .addThreshold({ color: 'yellow', value: 50 })
        .addThreshold({ color: 'red', value: 100 });

      local kubernetesAPIRequestsDuration =
        graphPanel.new(
          title='Kubernetes API Requests Duration',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_hideEmpty=true,
          legend_hideZero=true,
          legend_values=true,
          format='s'
        )
        .addTargets(
          [
            prometheus.target(
              'histogram_quantile(0.50, sum(rate(rest_client_request_latency_seconds_bucket{%(clusterLabel)s="$cluster",namespace="$namespace"}[5m])) by (le))' % $._config,
              legendFormat='P50',
              intervalFactor=1
            ),
            prometheus.target(
              'histogram_quantile(0.90, sum(rate(rest_client_request_latency_seconds_bucket{%(clusterLabel)s="$cluster",namespace="$namespace"}[5m])) by (le))' % $._config,
              legendFormat='P90',
              intervalFactor=1
            ),
            prometheus.target(
              'histogram_quantile(0.99, sum(rate(rest_client_request_latency_seconds_bucket{%(clusterLabel)s="$cluster",namespace="$namespace"}[5m])) by (le))' % $._config,
              legendFormat='P99',
              intervalFactor=1
            ),
          ]
        );

      local kubernetesAPIRequests =
        graphPanel.new(
          title='Kubernetes API Requests',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
        )
        .addTargets(
          [
            prometheus.target(
              'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[1m]))' % $._config,
              legendFormat='total',
              intervalFactor=1
            ),
            prometheus.target(
              'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",namespace="$namespace",code!~"2.."}[1m]))' % $._config,
              legendFormat='error',
              intervalFactor=1
            ),
          ]
        );

      local cpuUsage =
        graphPanel.new(
          title='CPU Usage',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          stack=true,
          format='s'
        )
        .addTarget(
          prometheus.target(
            'rate(process_cpu_seconds_total{%(clusterLabel)s="$cluster",namespace="$namespace",pod=~".*-controller-.*"}[1m])' % $._config,
            legendFormat='{{pod}}',
            intervalFactor=1
          ),
        );

      local memoryUsage =
        graphPanel.new(
          title='Memory Usage',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          stack=true,
          format='bytes'
        )
        .addTarget(
          prometheus.target(
            'rate(go_memstats_alloc_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace",pod=~".*-controller-.*"}[1m])' % $._config,
            legendFormat='{{pod}}',
            intervalFactor=1
          ),
        );

      local clusterReconciliationDuration =
        graphPanel.new(
          title='Cluster Reconciliation Duration',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          format='s'
        )
        .addTarget(
          prometheus.target(
            'workqueue_longest_running_processor_seconds{%(clusterLabel)s="$cluster",name="kustomization"}' % $._config,
            legendFormat='kustomization',
            intervalFactor=1
          ),
        );

      local clusterReconciliationOpsMin =
        graphPanel.new(
          title='Cluster Reconciliations ops/min',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          bars=true,
          lines=false,
          decimals=2,
          format='opm'
        )
        .addTargets(
          [
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="kustomization",result!="error"}[1m])) by (controller)' % $._config,
              legendFormat='successful reconciliations',
              intervalFactor=1
            ),
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="kustomization",result="error"}[1m])) by (controller)' % $._config,
              legendFormat='failed reconciliations',
              intervalFactor=1
            ),
          ]
        );

      local gitSourcesOpsMin =
        graphPanel.new(
          title='Git Sources ops/min',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          bars=true,
          lines=false,
          decimals=2,
          format='opm'
        )
        .addTargets(
          [
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="gitrepository",result!="error"}[1m]))' % $._config,
              legendFormat='successful git pulls',
              intervalFactor=1
            ),
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="gitrepository",result="error"}[1m]))' % $._config,
              legendFormat='failed git pulls',
              intervalFactor=1
            ),
          ]
        );

      local helmReleaseDuration =
        graphPanel.new(
          title='Helm',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          format='s'
        )
        .addTargets(
          [
            prometheus.target(
              'histogram_quantile(0.50, sum(rate(controller_runtime_reconcile_time_seconds_bucket{%(clusterLabel)s="$cluster",controller="helmrelease"}[5m])) by (le))' % $._config,
              legendFormat='P50',
              intervalFactor=1
            ),
            prometheus.target(
              'histogram_quantile(0.90, sum(rate(controller_runtime_reconcile_time_seconds_bucket{%(clusterLabel)s="$cluster",controller="helmrelease"}[5m])) by (le))' % $._config,
              legendFormat='P90',
              intervalFactor=1
            ),
            prometheus.target(
              'histogram_quantile(0.99, sum(rate(controller_runtime_reconcile_time_seconds_bucket{%(clusterLabel)s="$cluster",controller="helmrelease"}[5m])) by (le))' % $._config,
              legendFormat='P99',
              intervalFactor=1
            ),
          ]
        );

      local helmReleasesOpsMin =
        graphPanel.new(
          title='Helm Releases ops/min',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          bars=true,
          lines=false,
          decimals=2,
          format='opm'
        )
        .addTargets(
          [
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="helmrelease",result!="error"}[1m])) by (controller)' % $._config,
              legendFormat='successful reconciliations',
              intervalFactor=1
            ),
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="helmrelease",result="error"}[1m])) by (controller)' % $._config,
              legendFormat='failed reconciliations ',
              intervalFactor=1
            ),
          ]
        );

      local helmChartsOpsMin =
        graphPanel.new(
          title='Helm Charts ops/min',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_current=true,
          legend_values=true,
          bars=true,
          lines=false,
          decimals=2,
          format='opm'
        )
        .addTargets(
          [
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="helmchart",result!="error"}[1m])) by (controller)' % $._config,
              legendFormat='successful chart pulls',
              intervalFactor=1
            ),
            prometheus.target(
              'sum(increase(controller_runtime_reconcile_total{%(clusterLabel)s="$cluster",controller="helmchart",result="error"}[1m])) by (controller)' % $._config,
              legendFormat='failed chart pulls',
              intervalFactor=1
            ),
          ]
        );


      // FIXME: change to correct uid
      dashboard.new(
        'Flux / Control Plane',
        time_from='now-15m',
        uid='flux-control-plane-test',
        tags=['flux'],
      )
      .addTemplate(
        {
          current: {
            text: 'prometheus',
            value: 'prometheus',
          },
          hide: 0,
          label: null,
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: '',
          type: 'datasource',
        },
      )
      .addTemplate(
        template.new(
          'cluster',
          '$datasource',
          'label_values(gotk_reconcile_condition, %(clusterLabel)s)' % $._config,
          label='cluster',
          refresh='time',
          hide=if $._config.showMultiCluster then '' else 'variable',
          sort=1,
        )
      )
      .addTemplate(
        template.new(
          'namespace',
          '$datasource',
          'label_values(gotk_reconcile_condition{%(clusterLabel)s="$cluster"}, namespace)' % $._config,
          refresh='time',
          sort=1,
        )
      )
      .addPanel(controllers, gridPos={ h: 5, w: 6, x: 0, y: 0 })
      .addPanel(maxWorkQueue, gridPos={ h: 5, w: 6, x: 6, y: 0 })
      .addPanel(memory, gridPos={ h: 5, w: 6, x: 12, y: 0 })
      .addPanel(apiRequests, gridPos={ h: 5, w: 6, x: 18, y: 0 })
      .addPanel(
        row.new(
          title='Resource Usage'
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 5 }
      )
      .addPanel(kubernetesAPIRequestsDuration, gridPos={ h: 8, w: 12, x: 0, y: 6 })
      .addPanel(kubernetesAPIRequests, gridPos={ h: 8, w: 12, x: 12, y: 6 })
      .addPanel(cpuUsage, gridPos={ h: 11, w: 12, x: 0, y: 14 })
      .addPanel(memoryUsage, gridPos={ h: 11, w: 12, x: 12, y: 14 })
      .addPanel(
        row.new(
          title='Reconciliation Stats'
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 25 }
      )
      .addPanel(clusterReconciliationDuration, gridPos={ h: 8, w: 24, x: 0, y: 26 })
      .addPanel(clusterReconciliationOpsMin, gridPos={ h: 9, w: 12, x: 0, y: 34 })
      .addPanel(gitSourcesOpsMin, gridPos={ h: 9, w: 12, x: 12, y: 34 })
      .addPanel(
        row.new(
          title='Helm Stats'
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 43 }
      )
      .addPanel(helmReleaseDuration, gridPos={ h: 8, w: 24, x: 0, y: 44 })
      .addPanel(helmReleasesOpsMin, gridPos={ h: 9, w: 12, x: 0, y: 52 })
      .addPanel(helmChartsOpsMin, gridPos={ h: 9, w: 12, x: 12, y: 52 }),
  },
}
