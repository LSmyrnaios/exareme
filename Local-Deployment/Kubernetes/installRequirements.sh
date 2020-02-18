# To deploy the kubernetes successfully you have to setup the VMs as following:

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
&& sudo apt-mark unhold kubeadm kubectl kubectl \
&& sudo apt-get install -y kubeadm=1.15.10-00 kubectl=1.15.10-00 kubelet=1.15.10-00 \
&& sudo apt-mark hold kubeadm kubectl kubectl

# Install python in order for ansible to work and JQ for parsing the output of some commands.
sudo apt-get install -y python jq


# Also install kompose version 1.18.0 in the master node (which is used to deploy services on kubernetes)
# Version 1.19.0 has a bug.. and reports: "localhost:8080 connection refuced"
curl -L https://github.com/kubernetes/kompose/releases/download/v1.18.0/kompose-linux-amd64 -o kompose \
&& chmod +x kompose \
&& sudo mv ./kompose /usr/local/bin/kompose \
&& kompose version


# Configure the firewall-ports with the "firewallSetupForKubernetes.sh"
# execute it as Super User after a "sudo -i" and pass the argument <1> to allow one more port which is only for the master.
