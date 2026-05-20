#!/usr/bin/env bash
# deploy-infrastructure.sh — Init, plan and apply Terraform
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"
ACTION="${1:-plan}"   # plan | apply | destroy

# ── Validate prereqs ──────────────────────────────────────────────────────────
for cmd in terraform aws; do
  command -v "$cmd" &>/dev/null || { echo "✗ '$cmd' not found in PATH"; exit 1; }
done

# ── Required env vars ──────────────────────────────────────────────────────────
: "${TF_VAR_mongo_uri:?TF_VAR_mongo_uri must be set}"
: "${TF_VAR_jwt_secret:?TF_VAR_jwt_secret must be set}"
: "${TF_VAR_ecr_repository_url:?TF_VAR_ecr_repository_url must be set}"

echo "▶ Working directory: $TF_DIR"
echo "▶ Action: $ACTION"
cd "$TF_DIR"

# ── Init ──────────────────────────────────────────────────────────────────────
echo "▶ terraform init..."
terraform init -upgrade

# ── Validate ──────────────────────────────────────────────────────────────────
echo "▶ terraform validate..."
terraform validate

# ── Format check ──────────────────────────────────────────────────────────────
echo "▶ terraform fmt check..."
terraform fmt -check -recursive || {
  echo "  ✗ Format issues found. Run: terraform fmt -recursive"
  exit 1
}

case "$ACTION" in
  plan)
    echo "▶ terraform plan..."
    terraform plan -out=tfplan
    echo "✓ Plan saved to tfplan"
    ;;
  apply)
    echo "▶ terraform plan..."
    terraform plan -out=tfplan
    echo "▶ terraform apply..."
    terraform apply -auto-approve tfplan
    echo "✓ Apply complete"
    terraform output
    ;;
  destroy)
    echo "⚠️  DESTROY requested. Sleeping 10s — Ctrl-C to abort..."
    sleep 10
    terraform destroy -auto-approve
    echo "✓ Destroy complete"
    ;;
  *)
    echo "Unknown action: $ACTION. Use: plan | apply | destroy"
    exit 1
    ;;
esac
