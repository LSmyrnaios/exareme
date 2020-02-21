#!/bin/bash

# In order not to write the password each time (when using "sudo" for each command)..
# Do a "sudo -i" and then navigate to the path in which this script exists and execute it.

if [[ $# -ne 2 ]]; then
  echo -e "Invalid num of arguments given: $#
  Valid execution:
    ./firewallSetupForKubernetes.sh <runType (1: master, anything else: worker)> <resetMode (1: hard-reset firewalld (remove everything), anything else: soft-reset)>
  Please try again..\nExiting.."
  exit 1
fi

runType=$1  # 1: master, anything else: worker
resetMode=$2  # 1: hard, anything else: soft

########################################################################################################3333

# Shutdown firewalld
systemctl stop firewalld
systemctl disable firewalld

if [[ $resetMode -eq 1 ]]; then  # Delete config files only if needed! Be carefull as other needed configuration not present in this script will also be deleted..!
  echo -e "\nHard-resetting kubernetes..\n"
  kubeadm reset --force && rm -rf $HOME/.kube/config
  echo -e "\nHard-resetting docker..\n"
  docker system prune -a -f && docker service rm "$(docker service ls -q)"

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
apt update
apt install -y firewalld  # If "resetMode"="soft", then here we will just update it if necessary.
apt autoremove -y
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
firewall-cmd --permanent --add-port=4987/udp &&
firewall-cmd --permanent --add-port=80/tcp &&
firewall-cmd --permanent --add-port=4789/udp &&
firewall-cmd --zone=public --permanent --add-rich-rule='rule protocol value="esp" accept' # Protocol "50"

###############################################################################################################

echo "Setting Firewall-rules for Kubernetes cluster.."
firewall-cmd --zone=public --permanent --add-rich-rule='rule protocol value="ipip" accept'  # Protocol "4"
firewall-cmd --zone=public --permanent --add-masquerade
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

echo "Enabling br filtering.."
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

sysctl -w net.ipv4.ip_forward=1 && sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sysctl -p /etc/sysctl.conf 	# Enable port-forwarding

swapoff -a && sed -i '2s/^/#/' /etc/fstab	# Turn off swap (for Kubernetes)

##############################################################################################

# Start stopped serveces.
systemctl start docker kubelet
systemctl daemon-reload

echo "Finished"

#######################################################################################

# Troubleshootig:
# If firewalld was updated, you might have go back to your user with "CTRL + D" and run "sudo firewall-cmd --state" to have the firewalld authenticated by your user too (since your user will be connected though Ansible).
## If the worker container cannotconnect with the master, try this command on the master-node, it should fix the problem:
# sudo firewall-cmd --reload && sudo systemctl restart firewalld
# TODO - Find a way so this is not needed or to be done automatically..
