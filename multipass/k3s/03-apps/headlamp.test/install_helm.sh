#!/bin/bash
echo "--Installing Helm--"

if ! command -v git &> /dev/null; then
    echo "Git not found. Installing git..."
    sudo apt update && sudo apt install git -y
else
    echo "Git is already installed."
fi

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
echo "Executing get_helm.sh"
./get_helm.sh