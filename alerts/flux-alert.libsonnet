{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'flux-alert',
        rules: [
          {
            alert: 'FluxReconcilationFailed',
            expr: |||
              max(gotk_reconcile_condition{status="False",type="Ready"}) by (namespace, name, kind) == 1
            |||,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: '{{ $labels.kind }} {{ $labels.name }} reconcilation has been failed for more than 10 minutes in {{ $labels.exported_namespace }} namespace',
              runbook_url: '',
              summary: 'Flux {{ $labels.kind }} {{ $labels.name }} failed',
            },
            'for': '10m',
          },
        ],
      },
    ],
  },
}
