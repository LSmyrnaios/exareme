#!/bin/bash

# In order not to write the password each time (when using "sudo" for each command)..
# Run this script with "sudo".

if [[ $# -ne 2 ]]; then
  echo -e "Invalid num of arguments given: $#
  Valid execution:
    ./firewallSetupForKubernetes.sh <runType (1: master, anything else: worker)> <resetMode (1: hard-reset firewalld (remove everything), anything else: soft-reset)>
  Please try again..\nExiting.."
  exit 1
fi

runType=$1  # 1: master, anything else: worker
resetMode=$2  # 1: hard, anything else: soft

##########################################################################################################

# Shutdown firewalld
systemctl stop firewalld
systemctl disable firewalld

if [[ $resetMode -eq 1 ]]; then  # Delete config files only if needed! Be carefull as other needed configuration not present in this script will also be deleted..!
  echo -e "\nHard-resetting kubernetes..\n"
  kubeadm reset --force && rm -rf $HOME/.kube/config
  echo -e "\nHard-resetting docker..\n"
  docker system prune -a -f
  if [[ $runType -eq 1 ]]; then # Only the master-machine has the authority to run the following.
    # shellcheck disable=SC2046
    docker service rm $(docker service ls -q)
  fi

  # The iptables reset (that Kubernetes suggests), caused one of the worker-VMs (dl025) to crash (not the other though..).. so avoid it in general..
  # iptables -t nat -F && iptables -t mangle -F && iptables -F && iptables -X

  echo -e "\nPurging firewalld..\n"
  apt purge -y firewalld
  rm -rf /etc/systemd/system/firewalld
  rm -rf /etc/firewalld/

  systemctl daemon-reload
  systemctl reset-failed
fi

# Shutdown docker and kubernetes
systemctl stop docker kubelet

echo "Setting up Firewall-service.."
apt purge -y ufw # Purge ufw, in order to use ONLY the firewalld (avoid collisions).
apt update
apt install -y firewalld  # If "resetMode"="soft", then here we will just update it if necessary.
apt install -y ipip # Used by "calico" network plugin.
apt autoremove -y # Remove temporal packages.
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --state

#################################################################################################################

echo "Setting Firewall-rules for Docker.."
firewall-cmd --permanent --add-port=2376/tcp
if [[ $runType -eq 1 ]]; then # If we run the script on master.
	firewall-cmd --permanent --add-port=2377/tcp
fi
firewall-cmd --permanent --add-port=7946/tcp &&
firewall-cmd --permanent --add-port=7946/udp &&
firewall-cmd --permanent --add-port=4789/udp &&
firewall-cmd --permanent --add-port=80/tcp &&
#firewall-cmd --zone=public --permanent --add-rich-rule='rule protocol value="esp" accept' # Protocol "50"  # It was adviced to be disabled after an  exareme-connection-issue (also in Docker Swarm mode)
firewall-cmd --zone=public --permanent --add-masquerade

###############################################################################################################

echo "Setting Firewall-rules for Kubernetes cluster.."
firewall-cmd --zone=public --permanent --add-rich-rule='rule protocol value="ipip" accept'  # Protocol "4"
firewall-cmd --permanent --add-port=10250/tcp # Used by both master and worker.
firewall-cmd --permanent --add-port=10255/tcp # Used by both master and worker.

if [[ $runType -eq 1 ]]; then	# If we run the script on master.
  firewall-cmd --permanent --add-port=6443/tcp
  firewall-cmd --permanent --add-port=2379-2380/tcp
  firewall-cmd --permanent --add-port=10248/tcp
  firewall-cmd --permanent --add-port=10251-10252/tcp
  firewall-cmd --permanent --add-port=8001/tcp	# For the Kubernetes-Dashboard
  firewall-cmd --permanent --add-port=8080/tcp  # Used for kubernetes-api
fi

echo "Setting up Firewall-rules for EXAREME master and keystore"
firewall-cmd --permanent --add-port=8500/tcp  # For the Key-value store (master node)
firewall-cmd --permanent --add-port=9090/tcp  # For the Master (master node)
firewall-cmd --permanent --add-port=9000/tcp  # For the "Portainer" (master node)

echo "Setting up Firewall-rule for SSH.."
firewall-cmd --permanent --add-port=22/tcp	# Allow SSH : Important to not lose remote access to the VMs!

firewall-cmd --reload && systemctl restart firewalld  # Restart to use new configurations.
# Show what's enabled in firewalld
firewall-cmd --list-all

##################################################################################

echo "Enabling br filtering and port forwarding.."
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

sysctl -w net.ipv4.ip_forward=1 && sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sysctl -p /etc/sysctl.conf 	# Enable port-forwarding

swapoff -a && sed -i '2s/^/#/' /etc/fstab	# Turn off swap (for Kubernetes)

##############################################################################################

# Start stopped serveces.
systemctl start docker kubelet
systemctl daemon-reload
systemctl reset-failed

#############################################################################################

#echo "Using kube-iptables-tailer for clearer firewall debugging.."
# The are problems with this tha need to be addressed..
# TODO - Check this for updates: https://github.com/box/kube-iptables-tailer/issues/15
#git clone https://github.com/box/kube-iptables-tailer.git \
#&& cd kube-iptables-tailer \
#&& make container \
#&& chmod +w kube-iptables-tailer && rm -rf kube-iptables-tailer \
#&& iptables -A CHAIN_NAME -j LOG --log-prefix "KUBERNETES-LOG: "

echo "Finished"

#######################################################################################

# Troubleshootig:
# If firewalld was updated, you might have go back to your user with "CTRL + D" and run "sudo firewall-cmd --state" to have the firewalld authenticated by your user too (since your user will be connected though Ansible).
## If the worker container cannot connect with the master, try this command on the master-node, it should fix the problem:
# sudo systemctl restart firewalld
# TODO - Find a way so this is not needed or to be done automatically..
