resource "null_resource" "wait_for_k3s" {
  depends_on = [
    multipass_instance.k3s-master
  ]
  provisioner "local-exec" {
    interpreter = [
      "PowerShell",
      "-Command"
    ]
    command = <<EOT
Write-Host "Waiting for K3s kubeconfig..."
while ($true) {
    multipass exec k3s-master -- sudo test -f /etc/rancher/k3s/k3s.yaml

    if ($LASTEXITCODE -eq 0) {
        break
    }

    Start-Sleep -Seconds 5
}

Write-Host "K3s kubeconfig is ready"
EOT
  }
}

resource "null_resource" "kubeconfig" {
  depends_on = [
    null_resource.wait_for_k3s
  ]
  provisioner "local-exec" {
    interpreter = [
      "PowerShell",
      "-Command"
    ]
    command = <<EOT

Write-Host "Checking kubectl installation..."

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is required but was not found in PATH"
    exit 1
}
else {
    Write-Host "kubectl is installed:"
    kubectl version --client
}

Write-Host "Generating kubeconfig..."
$KubeDir = Join-Path $env:USERPROFILE ".kube"
$KubeFile = Join-Path $KubeDir "config.multipass.k3s"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $KubeDir | Out-Null

multipass exec k3s-master -- `
    sudo cat /etc/rancher/k3s/k3s.yaml |
    Out-File `
        -Encoding utf8 `
        $KubeFile

Write-Host "Updating Kubernetes API server address..."
(Get-Content $KubeFile) `
    -replace "127.0.0.1","${local.master_ip}" |
    Set-Content $KubeFile

Write-Host "Configuring kubectl context..."
kubectl `
    --kubeconfig $KubeFile `
    config rename-context default multipass-k3s

kubectl `
    --kubeconfig $KubeFile `
    config use-context multipass-k3s

Write-Host "Testing Kubernetes API..."
kubectl `
    --kubeconfig $KubeFile `
    get nodes

Write-Host ""
Write-Host "Kubeconfig created successfully:"
Write-Host $KubeFile
EOT
  }
}

output "kubeconfig_path" {
  description = "Generated kubeconfig path"
  value       = pathexpand("~/.kube/config.multipass.k3s")
}

output "kubectl_command" {
  description = "Command to access Multipass K3s cluster"
  value       = "kubectl --kubeconfig ~/.kube/config.multipass.k3s get nodes"
}