#!/bin/bash

set -e

DIRS=(
  "00-coredns"
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

    if [ "$dir" == "00-coredns" ]; then

        echo "================================="
        echo "Restarting CoreDNS"
        echo "================================="

        kubectl rollout restart deployment coredns -n kube-system

        echo "================================="
        echo "Waiting for CoreDNS rollout"
        echo "================================="

        kubectl rollout status deployment coredns -n kube-system --timeout=120s

    fi

done
