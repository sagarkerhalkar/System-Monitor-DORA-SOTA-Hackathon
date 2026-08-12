#!/usr/bin/env bash
set -euo pipefail

ARGO_ROLLOUTS_VERSION="v1.9.1"
ARGO_ROLLOUTS_MANIFEST_SHA256="78c82343803c2bbc13a36049e269a532dd67f25b7e2cb3603c99e31d8d8a40b5"
ARGO_ROLLOUTS_NAMESPACE="argo-rollouts"
MANIFEST_URL="https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}/install.yaml"

log() {
  printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require kubectl
require curl
require sha256sum
require mktemp

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
manifest="${tmp_dir}/argo-rollouts-install.yaml"

log "Verifying Kubernetes API connectivity"
kubectl get --raw=/readyz >/dev/null

log "Downloading pinned Argo Rollouts ${ARGO_ROLLOUTS_VERSION}"
curl -fsSL -o "$manifest" "$MANIFEST_URL"

log "Verifying release manifest SHA-256"
printf '%s  %s\n' \
  "$ARGO_ROLLOUTS_MANIFEST_SHA256" \
  "$manifest" | sha256sum -c -

log "Creating namespace"
kubectl create namespace "$ARGO_ROLLOUTS_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Applying Argo Rollouts"
kubectl apply \
  -n "$ARGO_ROLLOUTS_NAMESPACE" \
  -f "$manifest"

log "Waiting for controller"
kubectl -n "$ARGO_ROLLOUTS_NAMESPACE" \
  rollout status deployment/argo-rollouts \
  --timeout=5m

log "Verifying required CRDs"
for crd in \
  rollouts.argoproj.io \
  analysistemplates.argoproj.io \
  analysisruns.argoproj.io \
  experiments.argoproj.io
do
  kubectl get crd "$crd" >/dev/null
  echo "verified: $crd"
done

controller_image="$(
  kubectl -n "$ARGO_ROLLOUTS_NAMESPACE" \
    get deployment argo-rollouts \
    -o jsonpath='{.spec.template.spec.containers[0].image}'
)"

case "$controller_image" in
  *:"${ARGO_ROLLOUTS_VERSION}")
    ;;
  *)
    echo "Unexpected controller image: $controller_image" >&2
    exit 1
    ;;
esac

log "Argo Rollouts bootstrap passed"
echo "Controller image: $controller_image"
kubectl -n "$ARGO_ROLLOUTS_NAMESPACE" get pods -o wide
