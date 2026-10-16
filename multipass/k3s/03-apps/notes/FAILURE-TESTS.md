# Notes: Failure Simulation Tests

Hands-on experiments that show how the `notes` application behaves when things
break. All tests change only live cluster state, never the Git repository, so
nothing needs to be committed.

## Reference

| Component | Deployment | Replicas | State | Label |
|-----------|------------|----------|-------|-------|
| Frontend (nginx) | `notes-frontend` | 2 | stateless | `app=notes-frontend` |
| Backend (Python) | `notes-backend` | 1 | notes held **in memory** | `app=notes-backend` |

Namespace: `notes`. URL: `https://notes.multipass.k3s`.

> **Argo CD `selfHeal` is enabled.** Manual changes to Argo-managed resources
> (tests 4 and 5) are reverted to the state in Git within seconds to minutes.
> This is expected and is part of what the tests demonstrate.

## Setup

Open two terminals. In the first, watch the pods for the whole session:

```bash
kubectl -n notes get pods -o wide -w
```

Use the second for the commands below. Before each test, open the application
in a browser and add a few notes so you can see what survives.

Baseline check:

```bash
kubectl -n notes get pods
curl -k https://notes.multipass.k3s/api/health
```

Expected: 3 pods `Running` (2 frontend, 1 backend) and `{"status": "ok"}`.

---

## Test 1: Kill one frontend pod

**Goal:** show that a stateless tier with 2 replicas survives losing one pod.

```bash
kubectl -n notes delete pod $(kubectl -n notes get pod -l app=notes-frontend -o name | head -1)
```

While it runs, keep refreshing the page (or loop `curl`):

```bash
while true; do curl -sk -o /dev/null -w "%{http_code}\n" https://notes.multipass.k3s/; sleep 0.5; done
```

**Expected:**
- The remaining frontend pod keeps serving, so the status stays `200`.
- A replacement pod is created and becomes `Ready`.
- Notes are untouched, because the frontend holds no data.

**Variation:** delete both pods at once (`-l app=notes-frontend`). A short gap of
errors is possible until a new pod passes its `readinessProbe`.

---

## Test 2: Kill the backend pod

**Goal:** show the cost of keeping state in memory.

```bash
kubectl -n notes delete pod -l app=notes-backend
```

**Expected:**
- `/api` returns an error (usually `503`) for a few seconds.
- A new pod starts with a **different name** (shown as `backend pod:` under the
  note list).
- The note list is **empty**: all notes were lost.

**Lesson:** a single replica means downtime during restarts, and in-memory data
does not survive. Fix by adding a database or a persistent volume.

---

## Test 3: Rolling restart

**Goal:** compare a graceful rollout for each tier.

```bash
kubectl -n notes rollout restart deploy/notes-frontend
kubectl -n notes rollout status deploy/notes-frontend

kubectl -n notes rollout restart deploy/notes-backend
kubectl -n notes rollout status deploy/notes-backend
```

**Expected:**
- Frontend: zero visible downtime (new pods start before old ones stop).
- Backend: a brief interruption and the notes are lost (same cause as test 2).

---

## Test 4: Bad image (failed rollout)

**Goal:** show that a broken rollout does not take down the working version, and
that Argo CD reverts the manual change.

```bash
kubectl -n notes set image deploy/notes-frontend frontend=nginxinc/nginx-unprivileged:does-not-exist
kubectl -n notes rollout status deploy/notes-frontend --timeout=60s
kubectl -n notes get pods
```

**Expected:**
- The new pod shows `ErrImagePull` / `ImagePullBackOff`.
- The old pods keep running and the site stays up, because the rollout never
  gets a `Ready` replacement.
- Argo CD marks the app `OutOfSync` and then restores the Git version
  (`selfHeal`). Watch it in the Argo CD UI or with:

```bash
kubectl -n argocd get application notes -w
```

---

## Test 5: Out of memory (OOMKilled)

**Goal:** see a container killed for exceeding its memory limit and the
`RESTARTS` counter in action.

```bash
kubectl -n notes patch deploy notes-backend --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"8Mi"}]'

kubectl -n notes get pods -w
kubectl -n notes describe pod -l app=notes-backend | grep -A4 "Last State"
```

**Expected:**
- The new backend pod is killed on startup: `Last State: Terminated`,
  `Reason: OOMKilled`, then `CrashLoopBackOff` with a growing `RESTARTS` count.
- Argo CD then reverts the limit to the value from Git and a healthy pod
  returns.

---

## Test 6: Drain a node

**Goal:** show Kubernetes moving workloads off a node that is taken out of service.

```bash
kubectl get nodes
kubectl -n notes get pods -o wide

kubectl drain k3s-worker1 --ignore-daemonsets --delete-emptydir-data
kubectl -n notes get pods -o wide -w
```

**Expected:**
- Pods that ran on `k3s-worker1` are evicted and recreated on the remaining
  nodes. The frontend stays available if its other replica was on a different
  node.
- A backend pod that is moved loses its notes.

Restore the node afterwards:

```bash
kubectl uncordon k3s-worker1
```

Note: uncordoning does not move pods back; the scheduler only places new pods.

---

## Test 7: Node failure (hard)

**Goal:** observe the real, slower recovery when a node disappears without
warning. Start with enough free host RAM to restart the VM later.

```bash
multipass stop k3s-worker1
kubectl get nodes -w
kubectl -n notes get pods -o wide -w
```

**Expected:**
- The node goes `NotReady` after about 40 seconds.
- Pods on it are rescheduled only after the default toleration period
  (about 5 minutes), so the service on that node stays degraded in the meantime.

Restore:

```bash
multipass start k3s-worker1
```

---

## Cleanup and verification

After any test, confirm the application is back to normal:

```bash
kubectl -n argocd get application notes
kubectl -n notes get pods
curl -k https://notes.multipass.k3s/api/health
```

Expected: `Synced` / `Healthy`, 3 pods `Running`, and `{"status": "ok"}`.

If Argo CD does not reconcile on its own, force a refresh:

```bash
kubectl -n argocd annotate application notes argocd.argoproj.io/refresh=hard --overwrite
```

## Summary of lessons

| Test | What it demonstrates |
|------|----------------------|
| 1 | Replicas give availability for stateless services |
| 2, 3 | In-memory state is lost on restart; one replica means downtime |
| 4 | Rolling updates protect against a bad release |
| 4, 5 | Argo CD `selfHeal` reverts drift from Git |
| 5 | Resource limits and `OOMKilled` |
| 6, 7 | Node maintenance vs. real node failure and recovery time |
