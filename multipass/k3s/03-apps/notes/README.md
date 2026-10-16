# Notes

Sample two-tier application (frontend + backend) deployed by Argo CD.

```text
Browser --HTTPS--> Traefik (notes.multipass.k3s, TLS from cert-manager)
                     |-- /api/*  --> notes-backend  (Python, :8000, in-memory)
                     `-- /       --> notes-frontend (nginx, :8080, x2)
```

## Layout

| Path | Description |
|------|-------------|
| `app.yaml` | Discovered by the `platform-apps` ApplicationSet |
| `src/server.py` | Backend REST API (`GET/POST/DELETE /api/notes`, `GET /api/health`) |
| `src/index.html` | Frontend (static page calling `/api`) |
| `backend.yaml`, `frontend.yaml` | Deployments and Services |
| `ingressroute.yaml`, `certificate.yaml` | Traefik route and TLS certificate |
| `kustomization.yaml` | Generates ConfigMaps from `src/` |

No image build is needed: stock `python` and `nginx-unprivileged` images run the
code mounted from ConfigMaps. Editing `src/*` and pushing rolls the pods.

## Deploy

Merge to `main` (the ApplicationSet tracks `main`), then:

```bash
curl -k https://notes.multipass.k3s/api/health
curl -k -X POST https://notes.multipass.k3s/api/notes -H 'Content-Type: application/json' -d '{"text":"hello"}'
```

`notes.multipass.k3s` must resolve to the cluster, like the other `*.multipass.k3s` hosts.

## Limitations

Notes are stored in memory (lost on pod restart), so the backend runs a single
replica. Next steps: add PostgreSQL, or build real images in GitHub Actions
pushed to ghcr.io and tracked by Argo CD Image Updater.
