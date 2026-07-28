helm repo list
kubectl create namespace headlamp
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm install my-headlamp headlamp/headlamp --namespace headlamp
kubectl apply -f headlamp-ingress.yaml
kubectl create token my-headlamp --namespace headlamp
kubectl get ingress -n kube-system