#!/bin/bash
# check-cluster.sh

echo "=== SPRAWDZANIE STANU KLASTRA K3S ==="
echo

echo "1. Sprawdzanie namespace monitoring:"
kubectl get namespace monitoring 2>/dev/null || echo "Namespace monitoring nie istnieje"
echo

echo "2. Sprawdzanie zasobów w namespace monitoring:"
kubectl get all -n monitoring 2>/dev/null || echo "Brak zasobów w namespace monitoring"
echo

echo "3. Sprawdzanie instalacji Helm:"
if command -v helm &> /dev/null; then
    echo "Helm jest zainstalowany:"
    helm version --short
    echo
    
    echo "4. Lista wszystkich release'ów Helm:"
    helm list -A || echo "Brak release'ów Helm"
    echo
    
    echo "5. Sprawdzanie repozytoriów Helm:"
    helm repo list || echo "Brak repozytoriów Helm"
    echo
else
    echo "Helm nie jest zainstalowany"
fi

echo "6. Sprawdzanie wszystkich namespace'ów:"
kubectl get namespaces
echo

echo "7. Sprawdzanie podów w namespace monitoring:"
kubectl get pods -n monitoring 2>/dev/null || echo "Brak podów w namespace monitoring"
echo

echo "8. Sprawdzanie serwisów w namespace monitoring:"
kubectl get services -n monitoring 2>/dev/null || echo "Brak serwisów w namespace monitoring"
echo

echo "9. Sprawdzanie deploymentów w namespace monitoring:"
kubectl get deployments -n monitoring 2>/dev/null || echo "Brak deploymentów w namespace monitoring"
echo

echo "10. Sprawdzanie configmap w namespace monitoring:"
kubectl get configmaps -n monitoring 2>/dev/null || echo "Brak configmap w namespace monitoring"
echo

echo "=== KONIEC SPRAWDZANIA ==="
