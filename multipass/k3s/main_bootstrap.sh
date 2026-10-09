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
SECRETS_KV_URL="http://127.0.0.1:8500/v1/kv"
SECRETS_PREFIX="topsecret/"
KUBECONFIG_FILE="$HOME/.kube/config.multipass.k3s"

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

    echo "$0 --backup-secrets [file]"
    echo "  Export the Consul KV prefix topsecret/ to a password-encrypted file:"
    echo "  - Default file: ~/mate-lab-topsecret-<date>.enc (keep it outside this host)"
    echo ""

    echo -e "${RED_BG}${WHITE}$0 --restore-secrets <file>${RESET}"
    echo "  Decrypt a backup and import it into the Consul KV prefix topsecret/:"
    echo "  - Overwrites existing keys with the same names"
    echo ""

    echo "$0 --recover-secrets"
    echo "  Recover secrets missing in Consul topsecret/ from the running cluster:"
    echo "  - Sealed Secrets key, root CA (if valid > 1 year) and plain Secret manifests"
    echo "  - Never overwrites keys that already exist in Consul"
    echo ""

    echo "$0 --preflight [--build|--rebuild|--destroy|--clean|--backup-secrets|--restore-secrets|--recover-secrets]"
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
        echo "Start it from Git Bash in multipass/k3s with:" >&2
        echo "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File start-consul.ps1" >&2
        return 1
    fi

    if [ -z "$leader" ] || [ "$leader" = '""' ]; then
        echo "Consul is reachable, but no server leader has been elected." >&2
        return 1
    fi

    echo "Consul server leader: $leader"
}

check_consul_secrets() {
    local key
    local required_keys=(
        "topsecret/argocd/github-oauth-secret.yaml"
    )

    for key in "${required_keys[@]}"; do
        if ! curl --fail --silent --max-time 5 "$SECRETS_KV_URL/$key?keys" >/dev/null; then
            echo "Required secret not found in Consul KV: $key" >&2
            echo "Upload it, e.g.: curl -X PUT --data-binary @<file> $SECRETS_KV_URL/$key" >&2
            echo "or restore a backup: $0 --restore-secrets <file>" >&2
            return 1
        fi
    done

    if ! curl --fail --silent --max-time 5 "$SECRETS_KV_URL/topsecret/sealed-secrets/tls.key?keys" >/dev/null; then
        echo "Sealed Secrets key not found in Consul; a new one will be generated and all secrets re-sealed."
    fi

    if ! curl --fail --silent --max-time 5 "$SECRETS_KV_URL/topsecret/root-ca/tls.key?keys" >/dev/null; then
        echo "Root CA not found in Consul; a new one will be generated (run install-root-ca.sh after the build)."
    fi

    echo "Consul secrets (topsecret/): OK"
}

read_backup_password() {
    local confirm="$1"
    local password_repeat

    read -r -s -p "Backup password: " BACKUP_PASSWORD
    echo ""

    if [ -z "$BACKUP_PASSWORD" ]; then
        echo "Password must not be empty." >&2
        return 1
    fi

    if [ "$confirm" = "confirm" ]; then
        read -r -s -p "Repeat password: " password_repeat
        echo ""
        if [ "$BACKUP_PASSWORD" != "$password_repeat" ]; then
            echo "Passwords do not match." >&2
            return 1
        fi
    fi

    export BACKUP_PASSWORD
}

backup_secrets() {
    local target="${1:-$HOME/mate-lab-topsecret-$(date +%Y%m%d-%H%M%S).enc}"
    local export_json

    echo "================================="
    echo "BACKUP SECRETS (Consul topsecret/)"
    echo "================================="

    if [ -e "$target" ]; then
        echo "Target file already exists: $target" >&2
        return 1
    fi

    export_json="$(CONSUL_HTTP_ADDR=127.0.0.1:8500 consul kv export "$SECRETS_PREFIX")"
    if [ -z "$export_json" ] || [ "$export_json" = "[]" ]; then
        echo "Consul KV prefix '$SECRETS_PREFIX' is empty; nothing to back up." >&2
        return 1
    fi

    read_backup_password confirm

    printf '%s' "$export_json" | \
        openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -pass env:BACKUP_PASSWORD -out "$target"

    # Verify the backup decrypts back to the exported data before reporting success
    if [ "$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass env:BACKUP_PASSWORD -in "$target")" != "$export_json" ]; then
        echo "Backup verification failed: $target" >&2
        return 1
    fi

    unset BACKUP_PASSWORD
    echo "Encrypted backup written and verified: $target"
    echo "Store it outside this host (cloud drive, USB, password manager)."
}

restore_secrets() {
    local source_file="$1"
    local import_json

    echo "================================="
    echo "RESTORE SECRETS (Consul topsecret/)"
    echo "================================="

    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        echo "Usage: $0 --restore-secrets <file>" >&2
        return 1
    fi

    read_backup_password

    if ! import_json="$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass env:BACKUP_PASSWORD -in "$source_file" 2>/dev/null)"; then
        echo "Unable to decrypt $source_file (wrong password or corrupted file)." >&2
        return 1
    fi
    unset BACKUP_PASSWORD

    confirm_destructive_operation "This overwrites keys under Consul '$SECRETS_PREFIX' with the backup content. Continue? Type YES:" || exit 1

    printf '%s' "$import_json" | CONSUL_HTTP_ADDR=127.0.0.1:8500 consul kv import -
    echo "Secrets restored into Consul KV prefix: $SECRETS_PREFIX"
}

# Clean Secret manifest rebuilt from a live Secret: drops server-side metadata and the
# Argo CD tracking label, keeps name, namespace, labels, type and data.
SECRET_MANIFEST_TEMPLATE='apiVersion: v1
kind: Secret
metadata:
  name: {{.metadata.name}}
  namespace: {{.metadata.namespace}}
{{- if .metadata.labels}}
  labels:
{{- range $k, $v := .metadata.labels}}{{if ne $k "app.kubernetes.io/instance"}}
    {{$k}}: {{printf "%q" $v}}{{end}}{{end}}
{{- end}}
type: {{.type}}
data:
{{- range $k, $v := .data}}
  {{$k}}: {{$v}}
{{- end}}
'

recover_secret_to_consul() {
    local namespace="$1"
    local name="$2"
    local key="$3"
    local manifest

    if curl --fail --silent --max-time 5 "$SECRETS_KV_URL/$key?keys" >/dev/null; then
        echo "Already in Consul, skipped: $key"
        return 0
    fi

    if ! manifest="$(kubectl --kubeconfig "$KUBECONFIG_FILE" get secret -n "$namespace" "$name" \
        -o go-template="$SECRET_MANIFEST_TEMPLATE" 2>/dev/null)"; then
        echo "Secret $namespace/$name not found in the cluster; recreate $key manually." >&2
        return 1
    fi

    printf '%s\n' "$manifest" | \
        curl --fail --silent --show-error --max-time 5 -X PUT --data-binary @- "$SECRETS_KV_URL/$key" >/dev/null
    echo "Recovered from cluster: $namespace/$name -> $key"
}

recover_secrets() {
    local failed=0
    local sealed_file
    local app
    local ref
    local namespace
    local name

    echo "================================="
    echo "RECOVER SECRETS FROM THE CLUSTER"
    echo "================================="
    echo "Only keys missing in Consul '$SECRETS_PREFIX' are written."
    echo ""

    bash "$BOOTSTRAP_DIR/03-sealed-secrets/init-key.sh" || failed=1
    bash "$BOOTSTRAP_DIR/02-certificates/init-root-ca.sh" || failed=1

    recover_secret_to_consul argocd argocd-github-oauth-secret "topsecret/argocd/github-oauth-secret.yaml" || failed=1

    # Every app SealedSecret committed to Git points to the live Secret holding its plaintext
    for sealed_file in "$ROOT_DIR"/03-apps/*/sealed-*-secret.yaml; do
        [ -f "$sealed_file" ] || continue
        app="$(basename "$(dirname "$sealed_file")")"

        if ! ref="$(kubectl --kubeconfig "$KUBECONFIG_FILE" get -f "$sealed_file" \
            -o jsonpath='{.metadata.namespace} {.metadata.name}' 2>/dev/null)"; then
            echo "SealedSecret from $sealed_file not found in the cluster; recreate topsecret/apps/$app.yaml manually." >&2
            failed=1
            continue
        fi

        read -r namespace name <<< "$ref"
        recover_secret_to_consul "$namespace" "$name" "topsecret/apps/$app.yaml" || failed=1
    done

    echo ""
    if [ "$failed" -ne 0 ]; then
        echo "Some secrets could not be recovered; see the messages above and README (Disaster recovery)." >&2
        return 1
    fi

    echo "All secrets are present in Consul. Create a backup now: $0 --backup-secrets"
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
            require_commands git multipass terraform kubectl openssl base64 powershell.exe cygpath find rm sed tail cut grep sort curl
            check_project_layout
            resolve_gitops_source
            check_minimum_version multipass "$MIN_MULTIPASS_VERSION"
            check_minimum_version terraform "$MIN_TERRAFORM_VERSION"
            check_multipass_network
            check_consul
            check_consul_secrets
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
        --backup-secrets|--restore-secrets)
            require_commands consul openssl curl
            check_consul
            ;;
        --recover-secrets)
            require_commands kubectl openssl base64 curl
            check_consul
            if ! kubectl --kubeconfig "$KUBECONFIG_FILE" --request-timeout=5s get namespace kube-system -o name >/dev/null 2>&1; then
                echo "Kubernetes API is not reachable via $KUBECONFIG_FILE; recovery needs a running cluster." >&2
                return 1
            fi
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

    while IFS= read -r vm; do
        printf '  - %s\n' "$vm"
    done <<< "$INSTANCES"
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

    --backup-secrets)
        check_prerequisites --backup-secrets
        backup_secrets "${2:-}"
        ;;

    --restore-secrets)
        check_prerequisites --restore-secrets
        restore_secrets "${2:-}"
        ;;

    --recover-secrets)
        check_prerequisites --recover-secrets
        recover_secrets
        ;;

    --preflight)
        if [ "$#" -gt 2 ]; then
            echo "Usage: $0 --preflight [--build|--rebuild|--destroy|--clean|--backup-secrets|--restore-secrets|--recover-secrets]" >&2
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
