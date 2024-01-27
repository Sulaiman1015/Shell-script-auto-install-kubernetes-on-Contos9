 # use for linux centos 9 stream version

step 1: create a shell script to excute base configuration if not configon all nodes in kubernetes cluster, includ to Check root privileges and uninstall anything about kubernetes docker calico

k8s-base-config.sh :

    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sudo swapoff -a
    sudo sed -i '/ swap /s/^\(.*\)$/#\1/g' /etc/fstab
    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
    overlay
    br_netfilter
    EOF

    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    EOF
    sudo sysctl --system

    cat > /etc/sysconfig/modules/ipvs.modules <<EOF
    #!/bin/bash 
    modprobe -- ip_vs 
    modprobe -- ip_vs_rr 
    modprobe -- ip_vs_wrr 
    modprobe -- ip_vs_sh 
    modprobe -- nf_conntrack_ipv4 
    EOF

    chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4


    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    containerd config default | sudo tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    sudo systemctl start docker
    sudo systemctl enable docker

    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
    enabled=1
    gpgcheck=1
    gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
    exclude=kubelet kubeadm kubectl
    EOF

    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    sudo systemctl enable kubelet

step 2: create a shell script to excute initialization on master node in kubernetes cluster.

k8s-init-master.sh: 
    kubeadm init \
    --apiserver-advertise-address=192.168.78.165 \ 
    --service-cidr=10.96.0.0/16 \ 
    --pod-network-cidr=10.244.0.0/16 

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    export KUBECONFIG=/etc/kubernetes/admin.conf

    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
    
    kubectl edit cm kube-proxy -n kube-system #modify to mode:"ipvs" 
    kubectl get pod -A -o wide # get kube-proxy-xxxxx 
    kubectl delete pod kube-proxy-xxxxx -n kube-system
    kubectl get pod -A 

    print on console when excuted kubeadm init :
    kubeadm join 192.168.78.165:6443 --token --discovery-token-ca-cert-hash

step 3: create a shell script to u on master node in kubernetes cluster.

step 4: install dashbord:
    wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    
    kubectl apply -f recommended.yaml