#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Check if Docker and Kubernetes are installed before uninstalling
if command -v docker &>/dev/null && command -v kubectl &>/dev/null; then
    # Uninstall existing Docker and Kubernetes
    yum remove -y docker docker-ce docker-ce-cli containerd.io
    yum remove -y kubeadm kubectl kubelet kubernetes-cni kube*

    if [ -e /etc/kubernetes/ ]; then
        rm -rf /etc/kubernetes/
    fi

    if [ -e /var/lib/kubelet/ ]; then
        rm -rf /var/lib/kubelet/
    fi

    rm -rf /var/lib/etcd/ /var/lib/dockershim /var/run/kubernetes ~/.kube/
    rm -f /etc/calico/calico.yaml /etc/calico/calico-config.yaml
fi

# Update the system
yum update -y

echo "System is cleaned and updated."

# Basic Kubernetes configuration
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
swapoff -a
sed -i '/ swap /s/^\(.*\)$/#\1/g' /etc/fstab
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash 
modprobe -- ip_vs 
modprobe -- ip_vs_rr 
modprobe -- ip_vs_wrr 
modprobe -- ip_vs_sh 
modprobe -- nf_conntrack_ipv4 
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules && /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4

# Install Docker
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl start docker
systemctl enable docker

# Install Kubernetes
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet
