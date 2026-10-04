#!/usr/bin/env bash
# End-to-end test on a throwaway kind cluster:
#   deploy blue+green -> switch to green under load -> roll back to blue.
# Fails if any request returns non-200 during a switch, or if the wrong
# version answers after a switch. Never touches any other kube context.
set -euo pipefail

CLUSTER=bg-verify
NS=blue-green
cd "$(dirname "$0")/.."

# Private kubeconfig: kind writes its context here, so ~/.kube/config and its
# current-context stay untouched, and switch.sh can only reach the kind cluster.
TMP=$(mktemp -d)
export KUBECONFIG=$TMP/kubeconfig
k() { kubectl "$@"; }

cleanup() { kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT

kind create cluster --name "$CLUSTER" --wait 120s
for t in 1.0.0 1.0.1; do
  docker image inspect hakanyedibela/go-app:$t >/dev/null 2>&1 || docker pull -q hakanyedibela/go-app:$t
  kind load docker-image --name "$CLUSTER" hakanyedibela/go-app:$t
done

k apply -k manifests

# Proof that the namespace really enforces "restricted": a root Pod is rejected.
if k -n "$NS" run psa-probe --image=busybox:1.36 --restart=Never --dry-run=server -o name >/dev/null 2>&1; then
  echo "FAIL: non-compliant Pod was admitted, Pod Security not enforced"; exit 1
fi
echo "ok: non-compliant Pod rejected by Pod Security admission"
k -n "$NS" rollout status deploy/go-app-blue  --timeout=180s
k -n "$NS" rollout status deploy/go-app-green --timeout=180s

# The namespace enforces the "restricted" Pod Security Standard, so the test
# client needs a compliant securityContext too.
k -n "$NS" run client --image=curlimages/curl:8.10.1 --restart=Never \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":100,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"client","image":"curlimages/curl:8.10.1","command":["sleep","3600"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'
k -n "$NS" wait --for=condition=Ready pod/client --timeout=120s

# Number of developer records returned: 1.0.0 (blue) = 2, 1.0.1 (green) = 4
count() { k -n "$NS" exec client -- curl -sf "http://$1/developer" | grep -o first_name | wc -l | tr -d ' '; }

expect() {  # expect <service> <records>
  got=$(count "$1")
  [[ "$got" == "$2" ]] || { echo "FAIL: $1 returned $got records, expected $2"; exit 1; }
  echo "ok: $1 -> $2 records"
}

# Fire 400 requests at stable-svc while running the switch; report non-200s.
switch_under_load() {
  # shellcheck disable=SC2016  # $vars expand inside the client pod
  k -n "$NS" exec client -- sh -c '
    fails=0
    for i in $(seq 1 400); do
      c=$(curl -s -o /dev/null -w "%{http_code}" -m 2 http://stable-svc/developer)
      [ "$c" = 200 ] || fails=$((fails+1))
      sleep 0.02
    done
    echo $fails' > "$TMP/fails" &
  load=$!
  sleep 2
  ./scripts/switch.sh "$1"
  wait $load
  fails=$(cat "$TMP/fails")
  [[ "$fails" == 0 ]] || { echo "FAIL: $fails non-200 responses during switch to $1"; exit 1; }
  echo "ok: 0/400 failed requests during switch to $1"
}

echo "--- initial state"
expect stable-svc 2
expect preview-svc 4

echo "--- release: switch to green"
switch_under_load green
expect stable-svc 4
expect preview-svc 2

echo "--- rollback: switch to blue"
switch_under_load blue
expect stable-svc 2
expect preview-svc 4

echo "ALL CHECKS PASSED"
