#!/usr/bin/env bash
set -euo pipefail

AWS_ACCOUNT_ID="859934688742"
AWS_REGION="ap-south-1"
CLUSTER_NAME="sagar-system-monitor-hackathon"
ARGOCD_VERSION="v3.5.0"
MONITOR_SECRET_ID="/sagar-system-monitor/hackathon/monitor-admin-password"
MONITOR_PASSWORD_MIN_LENGTH=8

log() {
  printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

password_is_valid() {
  local value="$1"
  local classes=0
  local lowered

  [[ ${#value} -ge $MONITOR_PASSWORD_MIN_LENGTH ]] || return 1
  [[ "$value" =~ [a-z] ]] && ((classes += 1))
  [[ "$value" =~ [A-Z] ]] && ((classes += 1))
  [[ "$value" =~ [0-9] ]] && ((classes += 1))
  [[ "$value" =~ [^[:alnum:]] ]] && ((classes += 1))
  (( classes >= 3 )) || return 1

  lowered="${value,,}"
  case "$lowered" in
    admin@12345|password|password123|qwerty123|letmein) return 1 ;;
  esac
  return 0
}

generate_monitor_password() {
  # Guarantees uppercase + lowercase + digit + special, then adds 192 bits of random hex entropy.
  printf 'Aa1!%s' "$(openssl rand -hex 24)"
}

require aws
require kubectl
require openssl

log "Verifying AWS identity"
actual_account="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$actual_account" != "$AWS_ACCOUNT_ID" ]]; then
  echo "Wrong AWS account. Expected $AWS_ACCOUNT_ID, got $actual_account" >&2
  exit 1
fi

log "Configuring kubeconfig for private EKS cluster"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

log "Proving private Kubernetes API connectivity"
kubectl get --raw=/readyz >/dev/null
kubectl get nodes -o wide

log "Verifying EBS CSI add-on is ACTIVE"
ebs_status="$(aws eks describe-addon \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-ebs-csi-driver \
  --query addon.status \
  --output text 2>/dev/null || true)"
if [[ "$ebs_status" != "ACTIVE" ]]; then
  echo "aws-ebs-csi-driver is not ACTIVE (status: ${ebs_status:-missing}). Apply the current Terraform first." >&2
  exit 1
fi

log "Creating namespaces"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace system-monitor --dry-run=client -o yaml | kubectl apply -f -

log "Preparing Monitor runtime password from AWS Secrets Manager"
monitor_password="$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$MONITOR_SECRET_ID" \
  --query SecretString \
  --output text 2>/dev/null || true)"
monitor_secret_changed=false

if [[ -z "$monitor_password" || "$monitor_password" == "None" ]]; then
  monitor_password="$(generate_monitor_password)"
  monitor_secret_changed=true
  password_action="Generated and stored a new"
elif ! password_is_valid "$monitor_password"; then
  monitor_password="$(generate_monitor_password)"
  monitor_secret_changed=true
  password_action="Rotated an existing non-compliant"
else
  password_action="Reusing the existing compliant"
fi

if [[ "$monitor_secret_changed" == true ]]; then
  aws secretsmanager put-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$MONITOR_SECRET_ID" \
    --secret-string "$monitor_password" >/dev/null
fi
log "$password_action Monitor admin password in Secrets Manager"

kubectl -n system-monitor create secret generic monitor-runtime \
  --from-literal=admin-password="$monitor_password" \
  --dry-run=client -o yaml | kubectl apply -f -
unset monitor_password

if [[ "$monitor_secret_changed" == true ]] && kubectl -n system-monitor get deployment monitor >/dev/null 2>&1; then
  log "Restarting existing Monitor deployment so the rotated Secret is loaded"
  kubectl -n system-monitor rollout restart deployment/monitor
fi

log "Installing pinned Argo CD ${ARGOCD_VERSION}"
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

log "Waiting for core Argo CD deployments"
for deployment in argocd-server argocd-repo-server argocd-applicationset-controller; do
  kubectl -n argocd rollout status "deployment/${deployment}" --timeout=5m
done

log "Applying restricted System Monitor GitOps bootstrap"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kubectl apply -f "${repo_root}/gitops/argocd/bootstrap.yaml"

log "Waiting for Argo CD to report the application Synced"
for _ in $(seq 1 60); do
  sync_status="$(kubectl -n argocd get application system-monitor -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health_status="$(kubectl -n argocd get application system-monitor -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  printf 'sync=%s health=%s\n' "${sync_status:-unknown}" "${health_status:-unknown}"
  if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
    break
  fi
  sleep 10
done

sync_status="$(kubectl -n argocd get application system-monitor -o jsonpath='{.status.sync.status}')"
health_status="$(kubectl -n argocd get application system-monitor -o jsonpath='{.status.health.status}')"

if [[ "$sync_status" != "Synced" || "$health_status" != "Healthy" ]]; then
  echo "Argo CD application did not become Synced/Healthy." >&2
  kubectl -n argocd get application system-monitor -o yaml
  kubectl -n system-monitor get pods,pvc,svc -o wide
  exit 1
fi

log "GitOps bootstrap passed"
kubectl -n argocd get application system-monitor -o wide
kubectl -n system-monitor get pods,pvc,svc -o wide

echo
echo "Monitor admin username: hackathon-admin"
echo "Password remains stored in AWS Secrets Manager: ${MONITOR_SECRET_ID}"
echo "Use kubectl port-forward -n system-monitor svc/ui 8080:8080 for the first private-cluster demo."
