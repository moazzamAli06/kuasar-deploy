# Observability

Opt-in components; none is enabled by default.

| Component | What it adds | Needs |
|---|---|---|
| `components/observability` | an OpenTelemetry Collector (`otel-collector`) and `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317` for every service | Secret `otel-collector` with `OTLP_ENDPOINT` and `OTLP_AUTHORIZATION` (see [SECRETS.md](SECRETS.md)) and an OTLP/HTTP backend (Grafana Cloud, Datadog, Honeycomb, a self-hosted stack) |
| `components/alerts` | a `PrometheusRule` with generic alerts: crash loops, unavailable Deployments, failed migration Jobs, pods not ready, volumes nearly full | Prometheus Operator CRDs (kube-prometheus-stack or a managed Prometheus) and kube-state-metrics |

With the secret manager (`components/external-secrets`), also add `components/observability-external-secrets` so the `otel-collector` Secret is synced too.

Enable by adding the component to an overlay, for example in `overlays/production/kustomization.yaml`:
```yaml
components:
- ../../components/cloud-do
- ../../components/observability
- ../../components/alerts
```

Notes:
- The collector's egress uses the `kuasar.ai/egress-https` label, so it reaches public HTTPS endpoints (not private addresses). A backend on a private address needs its own NetworkPolicy.
- The alerts do not need application metrics. Application-level SLO alerts (latency, error rate) must be added once the services expose metrics: this repository does not know their metric names.
- Verify that the services export OTLP over gRPC. If they use `http/protobuf`, set the endpoint to port 4318.
- Set the `release:` label in `components/alerts/rules.yaml` to match your Prometheus `ruleSelector`.
