# Blue-Green Deployment in Kubernetes

Blue-green with plain Kubernetes objects: two Deployments, two Services, one
`kubectl patch`. No service mesh, no Ingress controller, no Argo Rollouts. That
is exactly the toolset you have in the CKAD exam.

## The idea

You run **two complete versions side by side**:

- **blue**: the version currently serving users (`hakanyedibela/go-app:1.0.0`)
- **green**: the new version, fully started but receiving no user traffic (`1.0.1`)

A Service does not point at a Deployment. It points at **every ready Pod whose
labels match its `selector`**. So a release is just changing one label value in
the selector of the production Service:

```
                     ┌───────────────────────────────┐
  users ──► stable-svc  selector: app=go-app,version=blue ──► go-app-blue  (3 Pods, v1.0.0)
                     └───────────────────────────────┘
  tests ──► preview-svc selector: app=go-app,version=green ─► go-app-green (3 Pods, v1.0.1)

  kubectl patch svc stable-svc ... version=green     # release
  kubectl patch svc stable-svc ... version=blue      # rollback, same command
```

Why this works without downtime:

- The Service object (and its ClusterIP and DNS name) **never goes away**. Only its
  endpoint list changes, and the change is atomic from the client's point of view.
- Green is **already running and Ready** before it gets traffic. Readiness probes
  guarantee a Pod only becomes an endpoint once it actually answers.
- Blue **keeps running** after the switch, so rollback is instant: patch back.

### Why not `kubectl delete svc` + `kubectl expose`?

The previous version of this repo did that. Between the delete and the expose there
is **no Service at all**: requests fail, DNS returns NXDOMAIN, and the new Service gets
a **new ClusterIP**. That is a stop-start deployment, not blue-green.

## Repository layout

```
manifests/
  namespace.yaml        namespace blue-green
  deploy-blue.yaml      go-app-blue,  labels app=go-app version=blue,  image 1.0.0
  deploy-green.yaml     go-app-green, labels app=go-app version=green, image 1.0.1
  svc-stable.yaml       stable-svc:  production traffic, starts on blue
  svc-preview.yaml      preview-svc: test traffic, always on the idle colour
  kustomization.yaml    lets you apply everything with kubectl apply -k
scripts/
  switch.sh             safe switch: refuses unless the target is fully Ready
  verify-kind.sh        end-to-end test on a throwaway kind cluster
```

## Walkthrough

### 1. Deploy everything

```shell
kubectl apply -k manifests/
kubectl -n blue-green rollout status deploy/go-app-blue
kubectl -n blue-green rollout status deploy/go-app-green
kubectl -n blue-green get deploy,svc,pods -L version
```

### 2. Test both versions in-cluster

Use a temporary Pod. The app returns 2 developers in 1.0.0 and 4 in 1.0.1.

```shell
kubectl -n blue-green run tmp --rm -it --restart=Never --image=busybox:1.36 -- \
  sh -c 'wget -qO- http://stable-svc/developer; echo; wget -qO- http://preview-svc/developer'
```

`stable-svc` answers with blue (2 records), `preview-svc` with green (4 records).
Run your smoke tests against `preview-svc` now, before any user sees green.

### 3. Check which Pods each Service really points at

```shell
kubectl -n blue-green get endpointslices -l kubernetes.io/service-name=stable-svc
kubectl -n blue-green get pods -l app=go-app,version=blue -o wide
```

Empty endpoints mean the selector matches no Ready Pod. That is the first thing
to check whenever a Service "doesn't work".

### 4. Release: switch production to green

```shell
kubectl -n blue-green patch svc stable-svc  -p '{"spec":{"selector":{"version":"green"}}}'
kubectl -n blue-green patch svc preview-svc -p '{"spec":{"selector":{"version":"blue"}}}'
```

Or with the guard rail (checks green is fully rolled out and Ready first):

```shell
./scripts/switch.sh green
```

`kubectl patch` with a JSON merge patch only changes the `version` key; `app`
stays. Alternative in the exam: `kubectl edit svc stable-svc` and change the value.

### 5. Rollback

Same command, other colour. Blue is still running, so this takes effect immediately.

```shell
./scripts/switch.sh blue
```

### 6. Next release

Blue is now the idle colour. Roll the new image onto it, test it on `preview-svc`,
then switch:

```shell
kubectl -n blue-green set image deploy/go-app-blue go-app=hakanyedibela/go-app:1.0.2
kubectl -n blue-green rollout status deploy/go-app-blue
# test http://preview-svc ...
./scripts/switch.sh blue
```

Then update the image tag in `manifests/deploy-blue.yaml` too, or the next
`kubectl apply -k` silently reverts it. Git must match the cluster.

### 7. Scale the idle colour down (optional)

Running both colours doubles resource usage. Once the release is confirmed,
scale the idle side down. Trade-off: rollback is then no longer instant, you
first have to scale up and wait for readiness.

```shell
kubectl -n blue-green scale deploy/go-app-blue --replicas=0
```

### Cleanup

```shell
kubectl delete ns blue-green
```

## What makes the manifests "best practice"

| Setting | Why |
|---|---|
| Deployment selector includes `version` | Blue and green must never select each other's Pods. Selectors are **immutable**, so get this right at creation time. |
| Service `targetPort: http` (named port) | The Service follows the container's port name, not a hard-coded number. |
| `readinessProbe` on `/developer` | A Pod only becomes a Service endpoint once the real endpoint answers. This is what makes the switch safe. |
| `livenessProbe` on `/` | Restarts a hung container. Deliberately looser than readiness. |
| `resources.requests` + memory `limits` | Scheduler can place Pods correctly; a memory leak gets OOM-killed instead of starving the node. No CPU limit, to avoid throttling. |
| `RollingUpdate` with `maxUnavailable: 0` | In-place updates (step 6) never drop below 3 ready Pods. |
| `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: ["ALL"]`, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault` | Meets the Pod Security Standard *restricted* profile, which `namespace.yaml` enforces (`pod-security.kubernetes.io/enforce: restricted`). The image itself runs as root; the Pod overrides it with UID 65534. |
| `automountServiceAccountToken: false` | The app never calls the API server, so it gets no token. |
| No `creationTimestamp: null` / `status: {}` | That is `--dry-run=client -o yaml` output noise. Delete it from generated YAML. |

## CKAD cheat sheet

Generate instead of typing YAML:

```shell
export do="--dry-run=client -o yaml"
kubectl create deploy go-app-green --image=hakanyedibela/go-app:1.0.1 --replicas=3 --port=18080 $do > green.yaml
# then edit: add the version label to metadata, selector, and template
```

`kubectl create deploy` only sets `app=<name>`. For blue-green you must add the
`version` label yourself, **in the selector and the Pod template**, before applying.

Create the Service imperatively, then point it at a colour:

```shell
kubectl -n blue-green create svc clusterip stable-svc --tcp=80:18080 $do > svc.yaml
# edit the selector to: app: go-app, version: blue
```

`kubectl expose deploy go-app-blue` copies the Deployment's full selector
(`version=blue` included) into the Service. Fine for the preview Service,
but you still switch it afterwards with `kubectl patch`.

Useful checks:

```shell
kubectl get pods --show-labels
kubectl get pods -l version=green
kubectl get svc stable-svc -o jsonpath='{.spec.selector}'
kubectl describe svc stable-svc           # look at "Endpoints:"
kubectl rollout history deploy/go-app-blue
kubectl rollout undo deploy/go-app-blue   # undo an image change within one colour
```

Blue-green vs. the built-in strategies:

| Strategy | Mechanism | Rollback | Cost |
|---|---|---|---|
| `RollingUpdate` (default) | Pods replaced gradually within one Deployment; old and new versions serve **at the same time** | `kubectl rollout undo`, gradual | No extra capacity |
| `Recreate` | All old Pods killed, then new ones started | Redeploy | Downtime |
| Blue-green (this repo) | Two Deployments, Service selector switch; exactly **one** version serves | Patch selector back, instant | 2x capacity while both run |
| Canary | Two Deployments behind **one** shared label, traffic split by replica ratio (e.g. 9 blue : 1 green) | Scale canary to 0 | Small extra capacity |

## Limits of this approach

- **Database schema changes** are not covered. Both colours must work with the same
  schema during the switch. Use expand/contract migrations.
- **Long-lived connections** (keep-alive, WebSocket, gRPC streams) to blue stay on
  blue after the switch until they reconnect. Keep blue running until they drain.
- **No traffic splitting.** A Service balances across all matching Pods equally. For
  percentage-based canaries you need an Ingress controller, Gateway API, or a mesh.
- **The image** (`hakanyedibela/go-app`) is **arm64-only** and ~900 MB (full `golang`
  base image). It will not start on amd64 nodes. A multi-stage build onto a
  `distroless`/`scratch` base with `--platform linux/amd64,linux/arm64` fixes both.

## Verify it yourself

`scripts/verify-kind.sh` creates a throwaway kind cluster, deploys both colours,
switches to green and back to blue **while sending 400 requests per switch**, and
fails on any non-200 response or a wrong version answering. It uses a private
kubeconfig, so your current `kubectl` context is never touched, and deletes the
cluster at the end.

```shell
./scripts/verify-kind.sh
```

Requires Docker, `kind`, and `kubectl`.
