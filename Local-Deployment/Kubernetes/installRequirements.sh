#!/bin/bash

# To deploy the kubernetes successfully you have to setup the VMs as following:

# ALL-VMs: install the following packages:

# install the required packages for docker and kubernetes
sudo apt-get update \
&& sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Install docker-ce
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
&& sudo apt-key fingerprint 0EBFCD88 \
&& sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
&& sudo apt-get update \
&& sudo apt-get install -y docker-ce docker-ce-cli containerd.io \

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
sudo systemctl daemon-reload \
&& sudo systemctl restart docker

sudo docker run hello-world

# Create docker super-user
groupadd docker \
&& sudo usermod -aG docker $USER \
&& newgrp docker


# And then install kubernetes:
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - \
&& echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list \
&& sudo apt-get update \
&& sudo apt-mark unhold kubeadm kubectl kubectl \
&& sudo apt-get install -y --allow-downgrades --allow-change-held-packages kubeadm=1.15.12-00 kubectl=1.15.12-00 kubelet=1.15.12-00 \
&& sudo apt-mark hold kubeadm kubectl kubectl

# Install python in order for exareme and ansible to work.
sudo apt-get install -y python


# ONLY THE MASTER: install the following packages..

if [[ $# -eq 1 && $1 -eq 1 ]]; then
  # Install "ansible" to run the commands on the VMs, "jq" for parsing the output of some kubernetes-commands and "git" to clone repos.
  sudo apt-get install -y ansible jq git

  # Also install kompose version 1.18.0 in the master node (which is used to deploy services on kubernetes)
  # Newer version 1.21.0, in order to work, it needs an extra parameter each time for server-declaration, but this parameter's support is missing for "kompose down"..
  # ektos ki an energopoihsw to "loopback address" sto firewalld..(?)
  curl -L https://github.com/kubernetes/kompose/releases/download/v1.18.0/kompose-linux-amd64 -o kompose \
  && chmod +x kompose \
  && sudo mv ./kompose /usr/local/bin/kompose \
  && kompose version
fi

# Configure the firewall-ports by running "sudo ./firewallSetupForKubernetes.sh <arg1> <arg2>"
# For the master-VM, pass the argument <arg1> = 1, other wise give any other number.
# For hard-reset of the firewall-system, pass the argument <arg2> = 1, other wise give any other number.
