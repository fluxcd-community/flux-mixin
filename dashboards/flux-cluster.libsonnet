local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

local barGaugePanel = grafana.barGaugePanel;
local dashboard = grafana.dashboard;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;
local row = grafana.row;
local statPanel = grafana.statPanel;
local tablePanel = grafana.tablePanel;
local template = grafana.template;

{
  grafanaDashboards+:: {
    'flux-cluster.json':
      local clusterReconcilers =
        statPanel.new(
          title='Cluster Reconcilers',
          datasource='$datasource',
          graphMode='none',
          reducerFunction='last',
        )
        .addTarget(
          prometheus.target(
            |||
              count(gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="True",kind=~"Kustomization|HelmRelease"})
              -
              sum(gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="Deleted",kind=~"Kustomization|HelmRelease"})
            ||| % $._config,
          )
        )
        .addThreshold({ color: 'blue', value: null })
        .addThreshold({ color: 'red', value: 100 });

      local failingReconcilers =
        statPanel.new(
          title='Failing Reconcilers',
          datasource='$datasource',
          reducerFunction='last',
        )
        .addTarget(
          prometheus.target('sum(gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="False",kind=~"Kustomization|HelmRelease"})' % $._config)
        )
        .addThreshold({ color: 'red', value: null });

      local kubernetesManifestSources =
        statPanel.new(
          title='Kubernetes Manifests Sources',
          datasource='$datasource',
          graphMode='none',
          reducerFunction='last',
        )
        .addTarget(
          prometheus.target(
            |||
              count(gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="True",kind=~"GitRepository|HelmRepository|Bucket"})
              -
              sum(gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="Deleted",kind=~"GitRepository|HelmRepository|Bucket"})
            ||| % $._config,
          )
        )
        .addThreshold({ color: 'blue', value: null })
        .addThreshold({ color: 'red', value: 100 });


      local failingSources =
        statPanel.new(
          title='Failing Sources',
          datasource='$datasource',
          reducerFunction='last',
        )
        .addTarget(
          prometheus.target(
            'sum(gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="False",kind=~"GitRepository|HelmRepository|Bucket"})' % $._config,
          )
        )
        .addThreshold({ color: 'red', value: 0 });

      local reconcilerOpsAvgSec =
        barGaugePanel.new(
          title='Reconciler ops avg. duration',
          datasource='$datasource',
          unit='s',
          thresholds=[
            { color: 'green', value: null },
            { color: 'yellow', value: 1 },
            { color: 'red', value: 61 },
          ]
        )
        .addTarget(
          prometheus.target(
            |||
              sum(rate(gotk_reconcile_duration_seconds_sum{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"Kustomization|HelmRelease"}[5m])) by (kind)
              /
              sum(rate(gotk_reconcile_duration_seconds_count{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"Kustomization|HelmRelease"}[5m])) by (kind)
            ||| % $._config,
            legendFormat='{{kind}}'
          )
        ) + {
          options: {
            orientation: 'horizontal',
            reduceOptions: {
              calcs: ['mean'],
              fields: '',
              values: false,
            },
          },
        };

      local sourceOpsAvgSec =
        barGaugePanel.new(
          title='Source ops avg. duration',
          datasource='$datasource',
          unit='s',
          thresholds=[
            { color: 'green', value: null },
            { color: 'yellow', value: 1 },
            { color: 'red', value: 61 },
          ]
        )
        .addTarget(
          prometheus.target(
            |||
              sum(rate(gotk_reconcile_duration_seconds_sum{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"GitRepository|HelmRepository|Bucket"}[5m])) by (kind)
              /
              sum(rate(gotk_reconcile_duration_seconds_count{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"GitRepository|HelmRepository|Bucket"}[5m])) by (kind)
            ||| % $._config,
            legendFormat='{{kind}}'
          )
        ) + {
          options: {
            orientation: 'horizontal',
            reduceOptions: {
              calcs: ['mean'],
              fields: '',
              values: false,
            },
          },
        };

      local statusPanelOverride = {
        // Ref: https://github.com/grafana/grafonnet-lib/issues/240
        styles: null,  // potential fix for grafonnet use type `table-old` format
        fieldConfig: {
          defaults: {
            mappings: [
              {
                from: '',
                id: 1,
                text: 'Ready',
                to: '',
                type: 1,
                value: '0',
              },
              {
                from: '',
                id: 2,
                text: 'Not Ready',
                to: '',
                type: 1,
                value: '1',
              },
            ],
            thresholds: {
              mode: 'absolute',
              steps: [
                {
                  color: 'blue',
                  value: null,
                },
                {
                  color: 'blue',
                  value: 0,
                },
                {
                  color: 'red',
                  value: 1,
                },
              ],
            },
          },
          overrides: [
            {
              matcher: {
                id: 'byName',
                options: 'Status',
              },
              properties: [
                {
                  id: 'custom.displayMode',
                  value: 'color-background',
                },
              ],
            },
          ],
        },
      };

      local statusPanelTransformationObj =
        [
          {
            id: 'organize',
            options: {
              excludeByName: {
                Time: true,
                __name__: true,
                app: true,
                cluster: true,
                container: true,
                endpoint: true,
                environment: true,
                exported_namespace: true,
                instance: true,
                job: true,
                kubernetes_namespace: true,
                kubernetes_pod_name: true,
                pod: true,
                pod_template_hash: true,
                project: true,
                prometheus: true,
                prometheus_replica: true,
                receive: true,
                status: true,
                tenant_id: true,
                type: true,
              },
              indexByName: {},
              renameByName: {
                Value: 'Status',
                kind: 'Kind',
                name: 'Name',
                namespace: 'Namespace',
              },
            },
          },
        ];

      local clusterReconciliationReadiness =
        tablePanel.new(
          title='Cluster reconciliation readiness',
          datasource='$datasource',
        )
        .addTarget(
          prometheus.target(
            'gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="False",kind=~"Kustomization|HelmRelease"}' % $._config,
            format='table',
            instant=true
          )
        )
        .addTransformations(
          statusPanelTransformationObj
        ) + statusPanelOverride;

      local sourceAcquisitionReadiness =
        tablePanel.new(
          title='Source acquisition readiness',
          datasource='$datasource',
        )
        .addTarget(
          prometheus.target(
            'gotk_reconcile_condition{%(clusterLabel)s="$cluster",namespace=~"$namespace",type="Ready",status="False",kind=~"GitRepository|HelmRepository|Bucket"}' % $._config,
            format='table',
            instant=true
          )
        )
        .addTransformations(
          statusPanelTransformationObj
        ) + statusPanelOverride;

      local clusterReconciliationDuration =
        graphPanel.new(
          title='Cluster reconciliation duration',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_rightSide=true,
          legend_hideEmpty=true,
          legend_hideZero=true,
          legend_values=true,
          format='s'
        )
        .addTarget(
          prometheus.target(
            |||
              sum(rate(gotk_reconcile_duration_seconds_sum{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"Kustomization|HelmRelease"}[5m])) by (kind, name)
              /
              sum(rate(gotk_reconcile_duration_seconds_count{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"Kustomization|HelmRelease"}[5m])) by (kind, name)
            ||| % $._config,
            legendFormat='{{kind}}/{{name}}'
          )
        );

      local sourceAcquisitionDuration =
        graphPanel.new(
          title='Source acquisition duration',
          datasource='$datasource',
          legend_alignAsTable=true,
          legend_avg=true,
          legend_rightSide=true,
          legend_hideEmpty=true,
          legend_hideZero=true,
          legend_values=true,
          format='s'
        )
        .addTarget(
          prometheus.target(
            |||
              sum(rate(gotk_reconcile_duration_seconds_sum{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"GitRepository|HelmRepository|Bucket"}[5m])) by (kind, name)
              /
              sum(rate(gotk_reconcile_duration_seconds_count{%(clusterLabel)s="$cluster",namespace=~"$namespace",kind=~"GitRepository|HelmRepository|Bucket"}[5m])) by (kind, name)
            ||| % $._config,
            legendFormat='{{kind}}/{{name}}'
          )
        );

      dashboard.new(
        'Flux / Cluster Stats',
        time_from='now-15m',
        uid='flux-cluster',
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
          includeAll=true,
          sort=1,
        )
      )
      .addPanel(clusterReconcilers, gridPos={ h: 5, w: 6, x: 0, y: 0 })
      .addPanel(failingReconcilers, gridPos={ h: 5, w: 6, x: 6, y: 0 })
      .addPanel(kubernetesManifestSources, gridPos={ h: 5, w: 6, x: 12, y: 0 })
      .addPanel(failingSources, gridPos={ h: 5, w: 6, x: 18, y: 0 })
      .addPanel(reconcilerOpsAvgSec, gridPos={ h: 4, w: 12, x: 0, y: 5 })
      .addPanel(sourceOpsAvgSec, gridPos={ h: 4, w: 12, x: 12, y: 5 })
      .addPanel(
        row.new(
          title='Status'
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 9 }
      )
      .addPanel(clusterReconciliationReadiness, gridPos={ h: 8, w: 12, x: 0, y: 10 })
      .addPanel(sourceAcquisitionReadiness, gridPos={ h: 8, w: 12, x: 12, y: 10 })
      .addPanel(
        row.new(
          title='Timing'
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 18 }
      )
      .addPanel(clusterReconciliationDuration, gridPos={ h: 8, w: 24, x: 0, y: 19 })
      .addPanel(sourceAcquisitionDuration, gridPos={ h: 8, w: 24, x: 0, y: 27 }),
  },
}
