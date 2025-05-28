#!/bin/bash

# Configure AWS CLI and update kubeconfig
aws configure
aws eks update-kubeconfig --region "us-east-1" --name "amazon-prime-cluster"

echo "Fetching service endpoints and credentials..."

# Step 1: Patch Prometheus service to LoadBalancer
kubectl patch svc kube-prometheus-kube-prome-prometheus -n prometheus -p '{"spec": {"type": "LoadBalancer"}}' || true

# Step 2: Wait for Prometheus LoadBalancer hostname/IP
echo "Waiting for Prometheus LoadBalancer IP..."
for i in {1..30}; do
    prometheus_url=$(kubectl get svc kube-prometheus-kube-prome-prometheus -n prometheus -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null)
    prometheus_ip=$(kubectl get svc kube-prometheus-kube-prome-prometheus -n prometheus -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null)

    if [ -n "$prometheus_url" ]; then
        prometheus_addr=$prometheus_url
        break
    elif [ -n "$prometheus_ip" ]; then
        prometheus_addr=$prometheus_ip
        break
    else
        echo "Attempt $i/30: Prometheus LoadBalancer not ready yet, retrying in 10s..."
        sleep 10
    fi
done

if [ -z "$prometheus_addr" ]; then
    echo "ERROR: Prometheus LoadBalancer hostname/IP not found after waiting."
    prometheus_addr="UNKNOWN"
fi

# Step 3: Get ArgoCD info
argo_url=$(kubectl get svc -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}" 2>/dev/null)
argo_ip=$(kubectl get svc -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}" 2>/dev/null)
if [ -n "$argo_url" ]; then
    argo_addr=$argo_url
elif [ -n "$argo_ip" ]; then
    argo_addr=$argo_ip
else
    argo_addr="UNKNOWN"
fi
argo_user="admin"
argo_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

# Step 4: Get Grafana info
grafana_url=$(kubectl get svc -n prometheus -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}" 2>/dev/null)
grafana_ip=$(kubectl get svc -n prometheus -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}" 2>/dev/null)
if [ -n "$grafana_url" ]; then
    grafana_addr=$grafana_url
elif [ -n "$grafana_ip" ]; then
    grafana_addr=$grafana_ip
else
    grafana_addr="UNKNOWN"
fi
grafana_user="admin"
grafana_password=$(kubectl get secret -n prometheus -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].data.admin-password}" | base64 --decode)

# Step 5: Print all info
echo "------------------------"
echo "ArgoCD URL: http://${argo_addr}"
echo "ArgoCD User: ${argo_user}"
echo "ArgoCD Password: ${argo_password}"
echo
echo "Prometheus URL: http://${prometheus_addr}:9090"
echo
echo "Grafana URL: http://${grafana_addr}"
echo "Grafana User: ${grafana_user}"
echo "Grafana Password: ${grafana_password}"
echo "------------------------"
