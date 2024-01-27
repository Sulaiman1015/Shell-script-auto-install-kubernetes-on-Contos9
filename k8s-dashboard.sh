#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Function to uninstall existing Kubernetes dashboard
uninstall_dashboard() {
    # Check if the Dashboard namespace exists
    if kubectl get namespace kubernetes-dashboard &> /dev/null; then

        # Forcefully delete pods in the kubernetes-dashboard namespace
        dashboard_pods=$(kubectl get pods -n kubernetes-dashboard -o jsonpath='{.items[*].metadata.name}')
        for pod in $dashboard_pods; do
            kubectl delete pod $pod -n kubernetes-dashboard --grace-period=0 --force
        done

        echo "Kubernetes Dashboard pods forcefully deleted."

        # Delete the service account, cluster role, and cluster role binding
        kubectl delete sa kubernetes-dashboard -n kubernetes-dashboard
        kubectl delete clusterrolebinding kubernetes-dashboard -n kubernetes-dashboard
        kubectl delete clusterrole kubernetes-dashboard -n kubernetes-dashboard

        # Delete the secret used for the Dashboard token
        kubectl delete secret kubernetes-dashboard-certs -n kubernetes-dashboard

        # Delete the deployment and service
        kubectl delete deployment kubernetes-dashboard -n kubernetes-dashboard
        kubectl delete service kubernetes-dashboard -n kubernetes-dashboard

        echo "Kubernetes Dashboard uninstallation completed."
    else
        echo "Kubernetes Dashboard namespace not found. Skipping uninstallation."
    fi
}

# Uninstall existing dashboard
uninstall_dashboard



# Create admin user for accessing Kubernetes Dashboard
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Add 'type: NodePort' before 'ports:'
sed -i '/spec:/a \ \ type: NodePort' recommended.yaml

# Add 'nodePort: 32000' after 'targetPort: 8443', same level with 'targetPort: 8443'
# sed -i '/targetPort: 8443/a \ \ \ \ \ \ nodePort: 32000' recommended.yaml

# Print the modified YAML file on the console
cat recommended.yaml

# Apply the modified YAML file
kubectl apply -f recommended.yaml

# delete old dashboard-admin
kubectl delete -f dashboard-admin.yaml

# create new one
cat << EOF > dashboard-admin.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

kubectl apply -f dashboard-admin.yaml

# Create ServiceAccount and ClusterRoleBinding for admin-user
# if ! kubectl get sa admin-user -n kubernetes-dashboard &> /dev/null; then
#     kubectl create sa admin-user -n kubernetes-dashboard
#     kubectl create clusterrolebinding admin-user-binding --clusterrole=admin --serviceaccount=kubernetes-dashboard:admin-user
#     echo "ServiceAccount and ClusterRoleBinding created for admin-user."
# else
#     echo "ServiceAccount admin-user already exists. Skipping creation."
# fi

# Get the token for the admin user
echo "Admin user token for accessing Kubernetes Dashboard:"
# kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}') | grep "token:" | awk '{print $2}'
kubectl -n kubernetes-dashboard create token admin-user
