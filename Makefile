.PHONY: alerts
alerts:
	mkdir -p files
	rm -rf files/alerts.yml
	jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts)' > files/alerts.yml

.PHONY: dashboards
dashboards:
	rm -rf files/dashboards
	mkdir -p files/dashboards
	jsonnet -J vendor -m files/dashboards -e '(import "mixin.libsonnet").grafanaDashboards'
