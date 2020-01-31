# To deploy the kubernetes successfully you have to setup the VMs as following:

# all-VM:
# install the following packages:
# install the docker-ce (check online tutorial)

sudo apt-get update \
&& sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
&& sudo apt-key fingerprint 0EBFCD88 \
&& sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
&& sudo apt-get update \
&& sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
&& sudo docker run hello-world


# And then install kubernetes:
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - \
&& echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list \
&& sudo apt-get update \
&& sudo apt-get install -y kubeadm=1.15.9-00 kubectl=1.15.9-00 kubelet=1.15.9-00

# Install JQ in for commands-ouput-parsing and python for ansible to work
sudo apt-get install -y jq python


# Also install kompose version 1.18.0 in the master node (which is used to deploy services on kubernetes)
# Version 1.19.0 has a bug.. and reports: "localhost:8080 connection refuced"
curl -L https://github.com/kubernetes/kompose/releases/download/v1.18.0/kompose-linux-amd64 -o kompose \
&& chmod +x kompose \
&& sudo mv ./kompose /usr/local/bin/kompose \
&& kompose version


# Configure the firewall-ports with the "firewallSetupForKubernetes.sh"
