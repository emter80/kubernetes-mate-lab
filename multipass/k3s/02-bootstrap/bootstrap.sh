#!/bin/bash

set -e

DIRS=(
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

for dir in "${DIRS[@]}"; do

    echo "================================="
    echo "Terraform init: $dir"
    echo "================================="

    cd "$dir"

    terraform init -upgrade

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
