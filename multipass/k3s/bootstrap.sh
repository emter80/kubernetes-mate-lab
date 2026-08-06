#!/bin/bash
set -e
ROOT_DIR="$(pwd)"
INFRA_DIR="01-infra"
BOOTSTRAP_DIR="02-bootstrap"
RED_BG='\033[41m'
WHITE='\033[97m'
RESET='\033[0m'

show_usage() {
    echo ""
    echo "Usage:"
    echo ""
    echo "./bootstrap.sh --apply"
    echo "  Normal bootstrap:"
    echo "  - Apply Terraform infrastructure (01-infra)"
    echo "  - Run Kubernetes bootstrap (02-bootstrap)"
    echo ""

    echo -e "${RED_BG}${WHITE}./bootstrap.sh --rebuild${RESET}"
    echo "  Full K3s rebuild:"
    echo "  - Show current k3s-* Multipass instances"
    echo "  - Ask for confirmation"
    echo "  - Delete only k3s-* Multipass VMs"
    echo "  - Purge deleted Multipass instances"
    echo "  - Remove Terraform cache/state"
    echo "  - Recreate infrastructure"
    echo "  - Run Kubernetes bootstrap"
    echo ""

    echo "./bootstrap.sh --clean"
    echo "  Cleanup Terraform local files only:"
    echo "  - Remove .terraform directories"
    echo "  - Remove terraform.tfstate files"
    echo "  - Do not remove Multipass VMs"
    echo ""

    echo "./bootstrap.sh --help"
    echo "  Show this help"
    echo ""
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

    read -p "Delete these instances? Type YES: " CONFIRM

    if [ "$CONFIRM" != "YES" ]; then
        echo "Cancelled"
        exit 1
    fi

    echo ""
    while read -r vm; do
        echo "Deleting: $vm"
        multipass delete "$vm"
    done <<< "$INSTANCES"

    echo ""
    echo "Purging deleted instances"

    multipass purge
    echo "Multipass cleanup completed"
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

    echo ""

    read -p "Continue Terraform cleanup? Type YES: " CONFIRM

    if [ "$CONFIRM" != "YES" ]; then
        echo "Cancelled"
        exit 1
    fi

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

    terraform_apply "$INFRA_DIR"

    echo "================================="
    echo "Running Kubernetes bootstrap"
    echo "================================="

    cd "$BOOTSTRAP_DIR"

    ./bootstrap.sh

    cd "$ROOT_DIR"
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

    echo "1. Delete Multipass instances:"
    echo "   - only names starting with k3s-"

    echo ""

    echo "2. Purge deleted Multipass instances"

    echo ""

    echo "3. Remove Terraform:"
    echo "   - .terraform directories"
    echo "   - terraform.tfstate files"

    echo ""

    echo "4. Recreate:"
    echo "   - K3s infrastructure"
    echo "   - Kubernetes bootstrap"

    echo ""

    read -p "Continue? Type YES: " CONFIRM

    if [ "$CONFIRM" != "YES" ]; then
        echo "Cancelled"
        exit 1
    fi

    delete_k3s_instances

    clean_terraform

    bootstrap_cluster
}

case "$1" in

    --apply)
        bootstrap_cluster
        ;;

    --rebuild)
        rebuild_cluster
        ;;

    --clean)
        clean_terraform
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
