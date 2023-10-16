#!/bin/bash 
# load kernel modules
modprobe overlay 
modprobe br_netfilter
echo -e "overlay\nbr_netfilter" > /etc/modules-load.d/k8s.conf
# Enable Sysctl parameters
cat > /etc/sysctl.d/k8s.conf << KUB
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
KUB
sysctl -p /etc/sysctl.d/k8s.conf
# Disable swap 
swapoff -a 
sed -i '/swap/ s/^/#/' /etc/fstab 
# Install Containerd
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install containerd.io -y
# Config containerd 
rm -rf /etc/containerd/config.toml
cat > /etc/containerd/config.toml << TOML
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      discard_unpacked_layers = true
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
TOML
# Add kubernetes repo and install it
dnf config-manager --add-repo https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
dnf install kubectl kubeadm kubelet -y
# Enable Services 
systemctl enable --now containerd.service kubelet.service
# Open firewall_ports 
ports=("2380" "6443" "10250" "10251" "10252")

for i in "${ports[@]}"; do
  firewall-cmd --add-port="${i}/udp" --permanent
  firewall-cmd --reload
done
# Those only on Control node
if [ $? -eq 0 ] 
then 
	echo " Create the cluster using : kubeadm init "
	echo " Install calico network plugin using : kubectl apply -f kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml "	
else 
	echo "someting wrong , check the guide again "
fi 
