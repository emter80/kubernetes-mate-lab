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

# Used when there is no cluster to plan against (DRY_RUN_OUTLINE=true): the kubernetes/helm
# providers cannot reach an API, so list what the layer would do from its declarations instead.
outline_layer() {
    local dir="$1"
    local script
    local resources
    local count
    local local_exec

    echo "================================="
    echo "Would create from scratch: $dir"
    echo "================================="

    for script in "$dir"/init-*.sh; do
        if [ -f "$script" ]; then
            echo "  run $(basename "$script"): $(sed -n '2p' "$script" | sed 's/^# *//')"
        fi
    done

    grep -hoE '^data "[^"]+" "[^"]+"' "$dir"/*.tf | sed -E 's/^data "([^"]+)" "([^"]+)"/  read data.\1.\2/' || true

    resources="$(grep -hoE '^resource "[^"]+" "[^"]+"' "$dir"/*.tf | sed -E 's/^resource "([^"]+)" "([^"]+)"/\1.\2/' || true)"
    count="$(printf '%s\n' "$resources" | grep -c . || true)"
    printf '%s\n' "$resources" | sed 's/^/  + /'

    local_exec="$(grep -h 'provisioner "local-exec"' "$dir"/*.tf | grep -c . || true)"
    if [ "$local_exec" -gt 0 ]; then
        echo "  ($local_exec local-exec command(s) run on this machine, e.g. kubectl, kubeseal, git, multipass)"
    fi

    PLAN_RESULTS+=("$dir: ${ORANGE_BG}to be created${RESET} ($count resources)")
}

if [ "$DRY_RUN" = true ]; then
    if [ "${DRY_RUN_OUTLINE:-false}" = true ]; then
        echo "No reachable cluster: showing what each layer would do from its declarations (not a real plan)."
        echo "Resource counts are the declared resources; for_each/count and Consul-dependent ones can differ."
    else
        echo "Skipping init-*.sh scripts in dry run (they write missing keys to Consul):"
        ls -1 ./*/init-*.sh 2>/dev/null | sed 's|^\./|  |' || true
    fi

    for dir in "${DIRS[@]}"; do
        if [ "${DRY_RUN_OUTLINE:-false}" = true ]; then
            outline_layer "$dir"
        else
            plan_layer "$dir"
        fi
    done

    echo "================================="
    echo "Dry run summary (02-bootstrap)"
    echo "================================="
    printf '  %b\n' "${PLAN_RESULTS[@]}"

    if [ "$PLAN_FAILED" -ne 0 ]; then
        echo "Some layers failed to plan; see the errors above." >&2
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
