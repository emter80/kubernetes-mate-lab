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
    echo "  - Remove Terraform cache/state"
    echo "  - Apply Terraform infrastructure (01-infra)"
    echo "  - Run Kubernetes bootstrap (02-bootstrap)"
    echo ""

    echo -e "${RED_BG}${WHITE}$0 --destroy${RESET}"
    echo "  Full K3s cluster destroy:"
    echo "  - Show current k3s-* Multipass instances"
    echo "  - Ask for confirmation"
    echo "  - Delete and purge only k3s-* Multipass VMs"
    echo "  - Remove Terraform cache/state"
    echo ""

    echo "$0 --clean"
    echo "  Cleanup Terraform local files only:"
    echo "  - Remove .terraform directories"
    echo "  - Remove terraform.tfstate files"
    echo "  - Do not remove Multipass VMs"
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

check_project_layout() {
    if [ ! -f "$INFRA_DIR/main.tf" ] || [ ! -f "$BOOTSTRAP_DIR/bootstrap.sh" ]; then
        echo "Expected project files were not found relative to $ROOT_DIR." >&2
        return 1
    fi
}

check_prerequisites() {
    local mode="$1"

    case "$mode" in
        --build|--rebuild)
            require_commands multipass terraform kubectl powershell.exe cygpath find rm sed tail cut grep sort
            check_project_layout
            check_minimum_version multipass "$MIN_MULTIPASS_VERSION"
            check_minimum_version terraform "$MIN_TERRAFORM_VERSION"
            check_multipass_network
            ;;
        --destroy)
            require_commands multipass find rm sed tail cut grep
            if ! multipass list >/dev/null 2>&1; then
                echo "Unable to connect to Multipass. Is the Multipass service running?" >&2
                return 1
            fi
            ;;
        --clean)
            require_commands find rm
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

    export HELM_REPOSITORY_CONFIG="$(cygpath -w "$repository_config")"
    export HELM_REPOSITORY_CACHE="$(cygpath -w "$repository_cache")"

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

    confirm_destructive_operation "This is destructive operation. Continue? Type YES:" || exit 1

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

    confirm_destructive_operation "This is destructive operation. Continue? Type YES:" || exit 1

    delete_k3s_instances
    clean_terraform
}

cluster_clean_terraform()
{
    echo "================================="
    echo "CLEAN TERRAFORM"
    echo "================================="

    confirm_destructive_operation "This is destructive operation. Continue? Type YES:" || exit 1

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
