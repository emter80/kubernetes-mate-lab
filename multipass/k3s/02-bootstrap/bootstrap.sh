#!/bin/bash

set -e

# DRY_RUN=true (set by main_bootstrap.sh --dry-run): terraform plan for every layer, nothing is applied.
DRY_RUN="${DRY_RUN:-false}"

DIRS=(
  "00-coredns"
  "01-cert-manager"
  "02-certificates"
  "03-sealed-secrets"
  "04-argocd"
  "05-ingress"
  "06-gitops"
  "07-secrets"
  "08-trust-manager"
  "09-oidc"
)

# Orange background for pending changes (only when writing to a terminal)
if [ -t 1 ]; then
    ORANGE_BG='\033[48;5;208m\033[30m'
    RESET='\033[0m'
else
    ORANGE_BG=""
    RESET=""
fi

PLAN_RESULTS=()
PLAN_FAILED=0

# terraform init that prints its (long) output only when it fails.
terraform_init_quiet() {
    local out

    if ! out="$(terraform init -input=false -no-color 2>&1)"; then
        printf '%s\n' "$out" >&2
        return 1
    fi
}

# A failing layer must not stop the remaining ones. terraform -detailed-exitcode: 0 = no changes,
# 2 = changes pending, 1 = error. The subshell keeps the working directory untouched.
plan_layer() {
    local dir="$1"
    local rc=0

    echo "================================="
    echo "Terraform plan (dry run): $dir"
    echo "================================="

    (cd "$dir" && terraform_init_quiet && terraform validate && terraform plan -input=false -detailed-exitcode) || rc=$?

    case "$rc" in
        0) PLAN_RESULTS+=("$dir: no changes") ;;
        2) PLAN_RESULTS+=("$dir: ${ORANGE_BG}changes pending${RESET}") ;;
        *) PLAN_RESULTS+=("$dir: ERROR"); PLAN_FAILED=1 ;;
    esac
}

if [ "$DRY_RUN" = true ]; then
    echo "Skipping init-*.sh scripts in dry run (they write missing keys to Consul):"
    ls -1 ./*/init-*.sh 2>/dev/null | sed 's|^\./|  |' || true

    for dir in "${DIRS[@]}"; do
        plan_layer "$dir"
    done

    echo "================================="
    echo "Dry run summary (02-bootstrap)"
    echo "================================="
    printf '  %b\n' "${PLAN_RESULTS[@]}"

    if [ "$PLAN_FAILED" -ne 0 ]; then
        echo "Some layers failed to plan. The layers need a running cluster and the Consul secrets" >&2
        echo "(topsecret/), so errors are expected before the first build." >&2
    fi

    exit "$PLAN_FAILED"
fi

for dir in "${DIRS[@]}"; do

    echo "================================="
    echo "Terraform init: $dir"
    echo "================================="

    cd "$dir"

    # Layer-specific preparation (e.g. persistent keys in Consul) that must exist before planning
    for init_script in init-*.sh; do
        if [ -f "$init_script" ]; then
            bash "./$init_script"
        fi
    done

    terraform init

    echo "================================="
    echo "Terraform validate: $dir"
    echo "================================="

    terraform validate

    echo "================================="
    echo "Terraform apply: $dir"
    echo "================================="

    terraform apply -auto-approve
    cd ..
done
