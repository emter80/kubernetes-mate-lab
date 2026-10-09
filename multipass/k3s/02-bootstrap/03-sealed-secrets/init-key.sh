#!/bin/bash
# Ensures the persistent Sealed Secrets key pair exists in Consul KV (topsecret/sealed-secrets/).
# Order: keep the key already in Consul -> export the active key from a running cluster -> generate a new one.
set -euo pipefail

KV_URL="http://127.0.0.1:8500/v1/kv/topsecret/sealed-secrets"
KUBECONFIG_FILE="$HOME/.kube/config.multipass.k3s"
KEY_LABEL="sealedsecrets.bitnami.com/sealed-secrets-key=active"

kv_get() {
    curl --fail --silent --max-time 5 "$KV_URL/$1?raw" || true
}

kv_put() {
    curl --fail --silent --show-error --max-time 5 -X PUT --data-binary "@$2" "$KV_URL/$1" >/dev/null
}

if [ -n "$(kv_get tls.crt)" ] && [ -n "$(kv_get tls.key)" ]; then
    echo "Sealed Secrets key found in Consul: topsecret/sealed-secrets/"
    exit 0
fi

WORK_DIR="$(mktemp -d)"
trap '[ -n "$WORK_DIR" ] && rm -rf -- "$WORK_DIR"' EXIT

key_names=""
if [ -f "$KUBECONFIG_FILE" ]; then
    key_names="$(kubectl --kubeconfig "$KUBECONFIG_FILE" --request-timeout=5s \
        get secret -n sealed-secrets -l "$KEY_LABEL" \
        -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
fi

if [ -n "$key_names" ]; then
    read -r -a keys <<< "$key_names"
    if [ "${#keys[@]}" -ne 1 ]; then
        echo "Found ${#keys[@]} active Sealed Secrets keys (${key_names}); back them up manually." >&2
        exit 1
    fi

    echo "Exporting active Sealed Secrets key from the cluster: ${keys[0]}"
    for field in crt key; do
        kubectl --kubeconfig "$KUBECONFIG_FILE" get secret -n sealed-secrets "${keys[0]}" \
            -o jsonpath="{.data.tls\\.${field}}" | base64 -d > "$WORK_DIR/tls.${field}"
    done
else
    echo "Generating a new Sealed Secrets key pair (RSA 4096, 10 years)"
    # Relative paths: MSYS_NO_PATHCONV keeps -subj intact but would also stop /c/... path conversion
    (
        cd "$WORK_DIR"
        MSYS_NO_PATHCONV=1 openssl req -x509 -nodes -newkey rsa:4096 \
            -keyout tls.key -out tls.crt -days 3650 \
            -subj "/CN=sealed-secret/O=sealed-secret" 2>/dev/null
    )
fi

kv_put tls.crt "$WORK_DIR/tls.crt"
kv_put tls.key "$WORK_DIR/tls.key"
echo "Sealed Secrets key stored in Consul: topsecret/sealed-secrets/ (back it up with: main_bootstrap.sh --backup-secrets)"
