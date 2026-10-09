#!/bin/bash
# Ensures the persistent root CA (multipass-root-ca) exists in Consul KV (topsecret/root-ca/).
# Order: keep the CA already in Consul -> export a long-lived CA from a running cluster -> generate a new one.
# A stable CA means Windows trusts the cluster certificates once, across rebuilds.
set -euo pipefail

KV_URL="http://127.0.0.1:8500/v1/kv/topsecret/root-ca"
KUBECONFIG_FILE="$HOME/.kube/config.multipass.k3s"

kv_get() {
    curl --fail --silent --max-time 5 "$KV_URL/$1?raw" || true
}

kv_put() {
    curl --fail --silent --show-error --max-time 5 -X PUT --data-binary "@$2" "$KV_URL/$1" >/dev/null
}

if [ -n "$(kv_get tls.crt)" ] && [ -n "$(kv_get tls.key)" ]; then
    echo "Root CA found in Consul: topsecret/root-ca/"
    exit 0
fi

WORK_DIR="$(mktemp -d)"
trap '[ -n "$WORK_DIR" ] && rm -rf -- "$WORK_DIR"' EXIT

# Recover the CA from a running cluster (e.g. Consul was lost). Short-lived CAs issued by
# cert-manager in older builds (90 days) are not worth keeping, so require > 1 year of validity.
exported=false
if [ -f "$KUBECONFIG_FILE" ] && kubectl --kubeconfig "$KUBECONFIG_FILE" --request-timeout=5s \
    get secret -n cert-manager multipass-root-ca >/dev/null 2>&1; then
    for field in crt key; do
        kubectl --kubeconfig "$KUBECONFIG_FILE" get secret -n cert-manager multipass-root-ca \
            -o jsonpath="{.data.tls\\.${field}}" | base64 -d > "$WORK_DIR/tls.${field}"
    done

    if openssl x509 -in "$WORK_DIR/tls.crt" -noout -checkend 31536000 >/dev/null 2>&1; then
        echo "Exporting root CA from the cluster (expires $(openssl x509 -in "$WORK_DIR/tls.crt" -noout -enddate | cut -d= -f2))"
        exported=true
    else
        echo "Cluster root CA expires within a year; generating a new long-lived one instead."
    fi
fi

if [ "$exported" = false ]; then
    echo "Generating a new root CA multipass-root-ca (ECDSA P-256, 10 years)"
    # Relative paths: MSYS_NO_PATHCONV keeps -subj intact but would also stop /c/... path conversion
    (
        cd "$WORK_DIR"
        MSYS_NO_PATHCONV=1 openssl req -x509 -new -nodes \
            -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
            -keyout tls.key -out tls.crt -days 3650 \
            -subj "/CN=multipass-root-ca" \
            -addext "basicConstraints=critical,CA:TRUE" \
            -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
    )
fi

kv_put tls.crt "$WORK_DIR/tls.crt"
kv_put tls.key "$WORK_DIR/tls.key"
echo "Root CA stored in Consul: topsecret/root-ca/ (trust it once with install-root-ca.sh after the build)"
