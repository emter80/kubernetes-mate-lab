#!/bin/bash

set -e

DIRS=(
  "01-cert-manager"
  "02-certificates"
  "03-argocd"
  "04-ingress"
  "05-gitops"
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
