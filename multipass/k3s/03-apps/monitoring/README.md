# Monitoring lab

This lab deploys standalone Prometheus and Grafana through the existing Argo CD ApplicationSet.
It intentionally omits the Prometheus Operator, Alertmanager, and Pushgateway to keep the footprint
lower than `kube-prometheus-stack`.

The Grafana Helm chart version used here (`10.5.15`) is marked deprecated upstream, so this is a
temporary learning setup rather than a production recommendation. Prometheus and Grafana use
ephemeral storage; Prometheus retains three days of metrics. Resource limits are defined in each
app's `values.yaml`.

Grafana is exposed through Traefik at `https://grafana.multipass.k3s`, using a certificate
issued by `multipass-ca` and Dex for login. Add the hostname to the same local DNS or hosts-file
configuration used by the other `*.multipass.k3s` applications.

Before syncing Grafana, add the `grafana` static client and its callback URL to the local
`multipass/k3s/02-bootstrap/07-secrets/topsecret/plain-dex-secret.yaml`, and create
`plain-grafana-secret.yaml` from `templates/template-grafana-secret.yaml` with the same client
secret. The Dex client template is in `templates/template-dex-secret.yaml`. Keep both plaintext
inputs local; the existing Sealed Secrets Terraform workflow generates encrypted manifests and
automatically commits and pushes them. Review that behavior before running it. The Grafana
Kustomization already references `sealed-grafana-secret.yaml`; its build will succeed once the
workflow generates and pushes that file.

Prometheus remains internal. Access it locally with port forwarding:

```bash
kubectl -n monitoring port-forward svc/prometheus-server 9090:80
```

Open <https://grafana.multipass.k3s> for Grafana or <http://localhost:9090> for Prometheus. Dex
authenticated users receive the Grafana Editor role in this lab; anonymous access and Grafana's
local password login are disabled.

Metrics are lost when the Prometheus pod is recreated. This is intentional for the lab; persistence,
and alerting should be configured before using a monitoring stack beyond local experimentation.