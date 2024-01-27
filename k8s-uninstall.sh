#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Define namespace
namespace=default

# Delete resources by type
delete_resources() {
    local resource_type=$1
    echo "Deleting $resource_type..."
    kubectl delete "$resource_type" --all --namespace="$namespace"
    if [ $? -ne 0 ]; then
        echo "Failed to delete $resource_type."
        exit 1
    fi
}

# Delete Deployments, StatefulSets, ReplicaSets, Pods, Services
delete_resources deployment
delete_resources statefulset
delete_resources replicaset
delete_resources pods --grace-period=0 --force
delete_resources service

# Delete ConfigMaps, Secrets, Ingresses, PersistentVolumeClaims
delete_resources configmap
delete_resources secret
delete_resources ingress
delete_resources persistentvolumeclaims

# Delete PersistentVolumes
echo "Deleting PersistentVolumes..."
kubectl delete persistentvolume --all

# Delete Roles, RoleBindings, ClusterRoles, ClusterRoleBindings
delete_resources role
delete_resources rolebinding
delete_resources clusterrole
delete_resources clusterrolebinding

# Delete Custom Resource Definitions (CRDs)
delete_resources crd

# Delete StorageClasses
delete_resources storageclass

# Delete Namespaces
echo "Deleting Namespaces..."
kubectl get namespaces --no-headers=true | awk '/Active/{print $1}' | grep -v kube | xargs kubectl delete namespace
