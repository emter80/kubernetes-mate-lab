#!/bin/bash
set -e

if [ -z "$MSYSTEM" ]; then
    echo "Script must be run via git bash"
    exit 0
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$ROOT_DIR/01-infra"
BOOTSTRAP_DIR="$ROOT_DIR/02-bootstrap"
MIN_MULTIPASS_VERSION="1.16.3"
MIN_TERRAFORM_VERSION="1.15.8"
RED_BG='\033[41m'
WHITE='\033[97m'
RESET='\033[0m'
GITOPS_REVISION=""
GITOPS_REPO_URL=""

show_usage() {
    echo ""
    echo "Usage:"
    echo ""
    echo "$0 --build"
    echo "  K3s cluster build from scratch:"
    echo "  - Ask for confirmation before applying changes"
    echo "  - Apply Terraform infrastructure (01-infra)"
    echo "  - Run Kubernetes bootstrap (02-bootstrap)"
    echo ""

    echo -e "${RED_BG}${WHITE}$0 --rebuild${RESET}"
    echo "  Full K3s cluster rebuild:"
    echo "  - Show current k3s-* Multipass instances"
    echo "  - Ask for confirmation"
    echo "  - Delete and purge only k3s-* Multipass VMs"
    echo "  - Remove local Terraform cache/state and Consul KV prefix terraform/"
    echo "  - Apply Terraform infrastructure (01-infra)"
    echo "  - Run Kubernetes bootstrap (02-bootstrap)"
    echo ""

    echo -e "${RED_BG}${WHITE}$0 --destroy${RESET}"
    echo "  Full K3s cluster destroy:"
    echo "  - Show current k3s-* Multipass instances"
    echo "  - Ask for confirmation"
    echo "  - Delete and purge only k3s-* Multipass VMs"
    echo "  - Remove local Terraform cache/state and Consul KV prefix terraform/"
    echo ""

    echo "$0 --clean"
    echo "  Remove Terraform local cache/state and the Consul KV prefix terraform/:"
    echo "  - Do not destroy managed resources or remove Multipass VMs"
    echo ""

    echo "$0 --preflight [--build|--rebuild|--destroy|--clean]"
    echo "  Run prerequisite checks only; defaults to --build checks"
    echo ""

    echo "$0 --help"
    echo "  Show this help"
    echo ""
}

require_commands() {
    local missing=()
    local command_name

    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            missing+=("$command_name")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Missing required command(s): ${missing[*]}" >&2
        return 1
    fi
}

check_minimum_version() {
    local command_name="$1"
    local minimum_version="$2"
    local version_output
    local actual_version
    local sorted_versions
    local lowest_version

    case "$command_name" in
        multipass)
            version_output="$(multipass version 2>&1)" || {
                echo "Unable to read Multipass version." >&2
                return 1
            }
            ;;
        terraform)
            version_output="$(terraform version 2>&1)" || {
                echo "Unable to read Terraform version." >&2
                return 1
            }
            ;;
    esac

    if [[ "$version_output" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        actual_version="${BASH_REMATCH[1]}"
    else
        echo "Could not parse $command_name version from its output." >&2
        return 1
    fi

    sorted_versions="$(printf '%s\n%s\n' "$actual_version" "$minimum_version" | sort -V)"
    lowest_version="${sorted_versions%%$'\n'*}"

    if [ "$lowest_version" != "$minimum_version" ]; then
        echo "$command_name $minimum_version or newer is required; found $actual_version." >&2
        return 1
    fi

    echo "$command_name version $actual_version: OK"
}

check_multipass_network() {
    local networks

    if ! networks="$(multipass networks 2>&1)"; then
        echo "Unable to query Multipass networks. Is the Multipass service running?" >&2
        return 1
    fi

    if ! printf '%s\n' "$networks" | grep -Eq '^[[:space:]]*multipass[[:space:]]'; then
        echo "Required Multipass network 'multipass' was not found." >&2
        echo "Create the Hyper-V virtual switch named 'multipass' and try again." >&2
        return 1
    fi

    echo "Multipass network 'multipass': OK"
}

check_consul() {
    local leader

    if ! leader="$(curl --fail --silent --max-time 5 http://127.0.0.1:8500/v1/status/leader)"; then
        echo "Unable to reach Consul at http://127.0.0.1:8500. Is the Consul server running?" >&2
        echo ">>Start Consul container"
        echo "  docker start consul"
        echo ">>OR"
        echo ">>Create Consul container from Git Bash with:" >&2
        echo "  docker rm -f consul 2>/dev/null || true" >&2
        echo "  MSYS_NO_PATHCONV=1 docker run -d --name consul \\" >&2
        echo "    -p 127.0.0.1:8500:8500 \\" >&2
        echo "    -v consul-data:/consul/data \\" >&2
        echo "    hashicorp/consul:2.0.4 \\" >&2
        echo "    agent -server -bootstrap-expect=1 -ui -client=0.0.0.0 -data-dir=/consul/data" >&2
        return 1
    fi

    if [ -z "$leader" ] || [ "$leader" = '""' ]; then
        echo "Consul is reachable, but no server leader has been elected." >&2
        return 1
    fi

    echo "Consul server leader: $leader"
}

delete_consul_terraform_states() {
    local consul_kv_url="http://127.0.0.1:8500/v1/kv"

    if ! curl --fail --silent --show-error --max-time 5 \
        --request DELETE "${consul_kv_url}/terraform/?recurse" >/dev/null; then
        echo "Failed to remove Consul KV prefix 'terraform/'. Local Terraform files were left untouched." >&2
        return 1
    fi

    echo "Removed Consul KV prefix: terraform/"
}

check_project_layout() {
    if [ ! -f "$INFRA_DIR/main.tf" ] || [ ! -f "$BOOTSTRAP_DIR/bootstrap.sh" ]; then
        echo "Expected project files were not found relative to $ROOT_DIR." >&2
        return 1
    fi
}

resolve_gitops_source() {
    local source_paths=(
        "main_bootstrap.sh"
        "02-bootstrap"
        "03-apps"
    )
    local branch
    local repo_url
    local remote_ref
    local remote_commit
    local local_commit

    if ! branch="$(git -C "$ROOT_DIR" branch --show-current)" || [ -z "$branch" ]; then
        echo "Unable to determine the current Git branch; detached HEAD is not supported." >&2
        return 1
    fi

    if ! repo_url="$(git -C "$ROOT_DIR" remote get-url origin)"; then
        echo "Unable to read the Git origin URL." >&2
        return 1
    fi

    case "$repo_url" in
        https://*@*|http://*@*)
            echo "Git origin URL must not contain embedded credentials." >&2
            return 1
            ;;
    esac

    if ! git -C "$ROOT_DIR" diff --quiet HEAD -- "${source_paths[@]}"; then
        echo "Commit and push the bootstrap, GitOps, and app changes before building the cluster." >&2
        return 1
    fi

    if [ -n "$(git -C "$ROOT_DIR" ls-files --others --exclude-standard -- "${source_paths[@]}")" ]; then
        echo "Commit and push untracked bootstrap, GitOps, and app files before building the cluster." >&2
        return 1
    fi

    if ! remote_ref="$(git -C "$ROOT_DIR" ls-remote --exit-code --heads "$repo_url" "refs/heads/$branch")"; then
        echo "Branch '$branch' was not found on origin; push it before building the cluster." >&2
        return 1
    fi

    remote_commit="${remote_ref%%$'\t'*}"
    local_commit="$(git -C "$ROOT_DIR" rev-parse HEAD)"
    if [ "$local_commit" != "$remote_commit" ]; then
        echo "Push the current commit on '$branch' before building; Argo CD reads the remote branch." >&2
        return 1
    fi

    GITOPS_REVISION="$branch"
    GITOPS_REPO_URL="$repo_url"
    echo "Argo CD source: $GITOPS_REPO_URL ($GITOPS_REVISION)"
}

check_prerequisites() {
    local mode="$1"

    case "$mode" in
        --build|--rebuild)
            require_commands git multipass terraform kubectl powershell.exe cygpath find rm sed tail cut grep sort curl
            check_project_layout
            resolve_gitops_source
            check_minimum_version multipass "$MIN_MULTIPASS_VERSION"
            check_minimum_version terraform "$MIN_TERRAFORM_VERSION"
            check_multipass_network
            check_consul
            ;;
        --destroy)
            require_commands multipass find rm sed tail cut grep curl
            check_consul
            if ! multipass list >/dev/null 2>&1; then
                echo "Unable to connect to Multipass. Is the Multipass service running?" >&2
                return 1
            fi
            ;;
        --clean)
            require_commands find rm curl
            check_consul
            ;;
        *)
            echo "No prerequisite checks are defined for '$mode'." >&2
            return 1
            ;;
    esac
}

configure_terraform_helm_environment() {
    local helm_home="$HOME/.cache/k3s-terraform-helm"
    local repository_config="$helm_home/repositories.yaml"
    local repository_cache="$helm_home/repository"

    mkdir -p "$repository_cache"
    printf '%s\n' \
        'apiVersion: ""' \
        'generated: "0001-01-01T00:00:00Z"' \
        'repositories: []' > "$repository_config"

    HELM_REPOSITORY_CONFIG="$(cygpath -w "$repository_config")"
    export HELM_REPOSITORY_CONFIG
    HELM_REPOSITORY_CACHE="$(cygpath -w "$repository_cache")"
    export HELM_REPOSITORY_CACHE

    echo "Terraform Helm repository config/cache isolated under $helm_home"
}

confirm_operation() {
    local prompt="$1"
    local confirmation

    read -r -p "$prompt " confirmation
    if [ "$confirmation" != "YES" ]; then
        echo "Cancelled"
        return 1
    fi
}

confirm_destructive_operation() {
    local prompt="$1"
    local confirmation

    printf '%b' "${RED_BG}${WHITE} $prompt ${RESET}"
    read -r confirmation

    if [ "$confirmation" != "YES" ]; then
        echo "Cancelled"
        return 1
    fi
}

get_k3s_instances() {
    multipass list --format csv | \
        tail -n +2 | \
        cut -d',' -f1 | \
        grep '^k3s-' || true
}

delete_k3s_instances() {
    echo "================================="
    echo "Searching k3s Multipass instances"
    echo "================================="

    INSTANCES=$(get_k3s_instances)

    if [ -z "$INSTANCES" ]; then
        echo "No k3s instances found"
        return
    fi

    echo ""
    echo "Instances to delete:"
    echo ""

    echo "$INSTANCES" | sed 's/^/  - /'
    echo ""

    while read -r vm; do
        echo "Deleting: $vm"
        multipass delete "$vm" -p
    done <<< "$INSTANCES"
}

clean_terraform() {

    echo "================================="
    echo "Terraform cleanup"
    echo "================================="

    echo ""
    echo "Files/directories to remove:"
    echo ""

    find "$ROOT_DIR" \
        -type d \
        -name ".terraform" \
        -print

    find "$ROOT_DIR" \
        -type f \
        \( \
            -name "terraform.tfstate" \
            -o -name "terraform.tfstate.backup" \
        \) \
        -print

    delete_consul_terraform_states

    find "$ROOT_DIR" \
        -type d \
        -name ".terraform" \
        -prune \
        -exec rm -rf {} \;

    find "$ROOT_DIR" \
        -type f \
        \( \
            -name "terraform.tfstate" \
            -o -name "terraform.tfstate.backup" \
        \) \
        -delete

    echo "Terraform cleanup completed"
}

terraform_apply() {

    local DIR=$1

    echo "================================="
    echo "Terraform apply: $DIR"
    echo "================================="

    cd "$DIR"

    terraform init -upgrade

    terraform validate

    terraform apply -auto-approve

    cd "$ROOT_DIR"
}

bootstrap_cluster() {

    echo "================================="
    echo "Creating K3s infrastructure"
    echo "================================="

    configure_terraform_helm_environment
    terraform_apply "$INFRA_DIR"

    echo "================================="
    echo "Running Kubernetes bootstrap"
    echo "================================="

    (
        export TF_VAR_git_revision="$GITOPS_REVISION"
        export TF_VAR_git_repo_url="$GITOPS_REPO_URL"
        cd "$BOOTSTRAP_DIR"
        ./bootstrap.sh
    )
}

rebuild_cluster() {

    echo "================================="
    echo "FULL K3S CLUSTER REBUILD"
    echo "================================="

    echo ""

    echo "Current Multipass instances:"
    echo ""
    multipass list

    echo ""
    echo "The following actions will be executed:"

    echo ""
    echo "1. Delete and purge Multipass instances:"
    echo "   - only names starting with k3s-"

    echo ""

    echo "2. Remove Terraform:"
    echo "   - .terraform directories"
    echo "   - terraform.tfstate files"

    echo ""

    echo "3. Recreate:"
    echo "   - K3s infrastructure"
    echo "   - Kubernetes bootstrap"

    echo ""

    confirm_destructive_operation "This deletes k3s-* VMs and local/Consul Terraform state before recreating the cluster. Continue? Type YES:" || exit 1

    delete_k3s_instances
    clean_terraform
    bootstrap_cluster
}

destroy_cluster() {
    local instances

    echo "================================="
    echo "FULL K3S CLUSTER DESTROY"
    echo "================================="

    echo ""

    echo "Current Multipass instances:"
    echo ""

    multipass list

    instances="$(get_k3s_instances)"
    if [ -z "$instances" ]; then
        echo "No k3s-* Multipass instances found. Nothing to destroy."
        return 0
    fi

    echo ""

    echo "The following actions will be executed:"
    echo ""

    echo "1. Delete and purge  Multipass instances:"
    echo "   - only names starting with k3s-"

    echo ""

    echo "2. Remove Terraform:"
    echo "   - .terraform directories"
    echo "   - terraform.tfstate files"

    echo ""

    confirm_destructive_operation "This deletes k3s-* VMs and local/Consul Terraform state. Continue? Type YES:" || exit 1

    delete_k3s_instances
    clean_terraform
}

cluster_clean_terraform()
{
    echo "================================="
    echo "CLEAN TERRAFORM"
    echo "================================="

    confirm_destructive_operation "This deletes local Terraform state and all Consul keys under terraform/; it does not destroy managed resources. Continue? Type YES:" || exit 1

    clean_terraform
}

case "$1" in

    --build)
        check_prerequisites --build
        confirm_operation "Build K3s cluster and apply its configuration? Type YES to continue:" || exit 1
        bootstrap_cluster
        ;;

    --rebuild)
        check_prerequisites --rebuild
        rebuild_cluster
        ;;

    --destroy)
        check_prerequisites --destroy
        destroy_cluster
        ;;

    --clean)
        check_prerequisites --clean
        cluster_clean_terraform
        ;;

    --preflight)
        if [ "$#" -gt 2 ]; then
            echo "Usage: $0 --preflight [--build|--rebuild|--destroy|--clean]" >&2
            exit 1
        fi

        PREFLIGHT_MODE="${2:---build}"
        check_prerequisites "$PREFLIGHT_MODE"
        echo "Preflight passed for $PREFLIGHT_MODE. No changes were made."
        ;;

    --help|-h|"")
        show_usage
        ;;

    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;

esac
