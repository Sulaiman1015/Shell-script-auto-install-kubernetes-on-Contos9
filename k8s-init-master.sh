#!/bin/bash

LOG_FILE="kubeadm_init.log"

# Redirect all output to the log file
exec > >(tee -a $LOG_FILE) 2>&1

echo "Script started at: $(date)"

# Get the IP address of the host
HOST_IP=$(hostname -I | awk '{print $1}')

# Initialize Kubernetes master node using kubeadm
kubeadm init \
    --apiserver-advertise-address=$HOST_IP \
    --service-cidr=10.96.0.0/16 \
    --pod-network-cidr=10.244.0.0/16

# Set up kubectl configuration
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Set KUBECONFIG environment variable
export KUBECONFIG=/etc/kubernetes/admin.conf

# Apply Calico network plugin
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Find the current mode in kube-proxy ConfigMap in kube-system namespace
current_mode=$(kubectl get configmap kube-proxy -n kube-system -o jsonpath='{.data.config}' | grep -oP 'mode: "\K[^"]+')

if [ "$current_mode" == "ipvs" ]; then
    echo "kube-proxy is already in ipvs mode."
else
    # Modify kube-proxy mode to "ipvs"
    kubectl get configmap kube-proxy -n kube-system -o yaml | \
    cat << EOF | kubectl apply -f -
apiVersion: v1
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    mode: "ipvs"
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
EOF

    echo "kube-proxy mode has been updated to ipvs."
fi

# Get the kube-proxy pod name
kube_proxy_pod=$(kubectl get pod -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[0].metadata.name}')

# Delete the kube-proxy pod to apply the changes
kubectl delete pod $kube_proxy_pod -n kube-system

# Display the pods in all namespaces
kubectl get pod -A

# Unset KUBECONFIG environment variable
unset KUBECONFIG

# Print the kubeadm join command
kubeadm_token=$(kubeadm token generate)
discovery_token_ca_cert_hash=$(kubeadm token create --print-join-command | grep -oP 'sha256:[a-f0-9]+')

echo "Run the following command on worker nodes to join the cluster:"
echo "kubeadm join 192.168.78.165:6443 --token $kubeadm_token --discovery-token-ca-cert-hash $discovery_token_ca_cert_hash"

echo "Script completed at: $(date)"


