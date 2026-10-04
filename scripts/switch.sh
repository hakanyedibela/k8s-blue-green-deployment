#!/usr/bin/env bash
# Switch production traffic to a colour: ./scripts/switch.sh green
# Refuses to switch unless the target Deployment is fully rolled out and ready.
set -euo pipefail

NS=${NS:-blue-green}
TARGET=${1:?usage: $0 <blue|green>}
case "$TARGET" in
  blue)  IDLE=green ;;
  green) IDLE=blue ;;
  *) echo "colour must be blue or green" >&2; exit 2 ;;
esac

echo "context: $(kubectl config current-context)  namespace: $NS"

kubectl -n "$NS" rollout status deploy/go-app-"$TARGET" --timeout=120s

desired=$(kubectl -n "$NS" get deploy go-app-"$TARGET" -o jsonpath='{.spec.replicas}')
ready=$(kubectl -n "$NS" get deploy go-app-"$TARGET" -o jsonpath='{.status.readyReplicas}')
if [[ "${ready:-0}" -lt 1 || "${ready:-0}" -ne "$desired" ]]; then
  echo "go-app-$TARGET not ready ($ready/$desired), not switching" >&2
  exit 1
fi

kubectl -n "$NS" patch svc stable-svc  -p "{\"spec\":{\"selector\":{\"version\":\"$TARGET\"}}}"
kubectl -n "$NS" patch svc preview-svc -p "{\"spec\":{\"selector\":{\"version\":\"$IDLE\"}}}"

kubectl -n "$NS" get svc -L version -o wide
