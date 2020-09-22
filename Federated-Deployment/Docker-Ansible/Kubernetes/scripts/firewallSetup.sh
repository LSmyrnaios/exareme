#!/bin/bash

# In order not to write the password each time (when using "sudo" for each command)..
# Run this script with "sudo".

if [[ $# -ne 3 ]]; then
  echo -e "Invalid num of arguments given: $#
  Valid execution:
    ./firewallSetup.sh <clusterMemberType (1: master, anything else: worker)> <resetMode (1: hard-reset firewalld (remove everything), anything else: soft-reset)>
    <orchestratorType (1: Kubernetes, anything else: Docker Swarm)>
  Please try again..\nExiting.."
  exit 1
fi

clusterMemberType=$1  # 1: master, anything else: worker
resetMode=$2  # 1: hard, anything else: soft
orchestratorType=$3 # 1: Kubernetes, anything else: Docker Swarm

##########################################################################################################

# Shutdown firewalld
systemctl stop firewalld
systemctl disable firewalld

if [[ $resetMode -eq 1 ]]; then  # Delete config files only if needed! Be careful as other needed configuration not present in this script will also be deleted..!
  if [[ $orchestratorType -eq 1 ]]; then
    echo -e "\nHard-resetting kubernetes..\n"
    kubeadm reset --force && rm -rf $HOME/.kube/config
  fi
  echo -e "\nHard-resetting docker..\n"
  docker system prune -a -f
  if [[ $clusterMemberType -eq 1 ]]; then # Only the master-machine has the authority to run the following.
    # shellcheck disable=SC2046
    docker service rm $(docker service ls -q)
  fi

  # The iptables reset (that Kubernetes suggests), caused one of the worker-VMs (dl025) to crash (not the other though..).. so avoid it in general..
  ## iptables -t nat -F && iptables -t mangle -F && iptables -F && iptables -X

  echo -e "\nPurging firewalld..\n"
  apt purge -y firewalld
  rm -rf /etc/systemd/system/firewalld
  rm -rf /etc/firewalld/

  systemctl daemon-reload
  systemctl reset-failed
fi

# Shutdown docker and kubernetes
if [[ $orchestratorType -eq 1 ]]; then  # If we have Kubernetes
  systemctl stop docker kubelet # For Kubernetes, we also reset docker.
else
  systemctl stop docker
fi

echo "Setting up Firewall-service.."
apt purge -y ufw # Purge ufw, in order to use ONLY the firewalld (avoid collisions).
apt update
apt install -y firewalld  # If "resetMode"="soft", then here we will just update it, if necessary.
if [[ $orchestratorType -eq 1 ]]; then  # It is used by Kubernetes
  apt install -y ipip # Used by "calico" network plugin.
fi
apt install -y ssh # Used for remote access.
apt autoremove -y # Remove temporal packages.
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --state


if [[ $orchestratorType -eq 1 ]]; then  # If we have Kubernetes
  echo "Setting Firewall-rules for Kubernetes cluster.."
  firewall-cmd --zone=public --permanent --add-rich-rule='rule protocol value="ipip" accept'  # Protocol "4" for "calico"-network-plugin.
  #firewall-cmd --add-masquerade --permanent
  firewall-cmd --permanent --add-port=10250/tcp # Used by both master and worker.
  firewall-cmd --permanent --add-port=10255/tcp # Used by both master and worker.
  #firewall-cmd --permanent --add-port=8472/udp

  #firewall-cmd --permanent --add-port=8443/tcp  # For ingress controller.

  # Ports for Weave Net Network Plugin (used in DARE). TODO - Check why it doesn't work..
  #firewall-cmd --permanent --add-port=6783/tcp
  #firewall-cmd --permanent --add-port=6783-6784/udp

  if [[ $clusterMemberType -eq 1 ]]; then	# If we run the script on master.
    firewall-cmd --permanent --add-port=6443/tcp
    firewall-cmd --permanent --add-port=2379-2380/tcp
    #firewall-cmd --permanent --add-port=10248/tcp # Not sure if it's needed.
    firewall-cmd --permanent --add-port=10251-10252/tcp

    firewall-cmd --permanent --add-port=8080/tcp  # Used for kubernetes-api
    firewall-cmd --permanent --add-port=8001/tcp	# For the Kubernetes-Dashboard

    # only if you want NodePorts exposed on control plane IP as well for master
    #firewall-cmd --permanent --add-port=30000-32767/tcp

  else
    firewall-cmd --permanent --add-port=30000-32767/tcp # Only for worker-nodes
  fi
else # If we have Docker Swarm
  #################################################################################################################
  echo "Setting Firewall-rules for Docker Swarm.."
  if [[ $clusterMemberType -eq 1 ]]; then # If we run the script on master.
    firewall-cmd --permanent --add-port=9000/tcp  # For the "Portainer" (master node)
    firewall-cmd --permanent --add-port=2377/tcp
  fi
  firewall-cmd --permanent --add-port=2376/tcp
  firewall-cmd --permanent --add-port=7946/tcp
  firewall-cmd --permanent --add-port=7946/udp
  firewall-cmd --permanent --add-port=4789/udp
  firewall-cmd --permanent --add-port=80/tcp
  #firewall-cmd --zone=public --permanent --add-rich-rule='rule protocol value="esp" accept'  # Protocol "50" # It was adviced to be disabled after an  exareme-connection-issue (also in Docker Swarm mode)
  firewall-cmd --zone=public --permanent --add-masquerade
  ###############################################################################################################
fi

if [[ $clusterMemberType -eq 1 ]]; then # If we run the script on master.
  echo "Setting up Firewall-rule for the keystore."
  firewall-cmd --permanent --add-port=8500/tcp  # For the Key-value store (master node)
fi

echo "Setting up Firewall-rule for the master and worker services."
firewall-cmd --permanent --add-port=9090/tcp  # For the master and worker services.

echo "Setting up Firewall-rule for SSH.."
firewall-cmd --permanent --add-port=22/tcp	# Allow SSH : Important to not lose remote access to the VMs!

firewall-cmd --reload # Reload firewalld with the new ports-configuration.


##################################################################################
echo "Enabling br filtering and port forwarding.."
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

sysctl -w net.ipv4.ip_forward=1 && sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sysctl -p /etc/sysctl.conf 	# Enable port-forwarding

if [[ $orchestratorType -eq 1 ]]; then  # If we have Kubernetes
  swapoff -a && sed -i '2s/^/#/' /etc/fstab	# Turn off swap (for Kubernetes)
fi
##############################################################################################

# Restart the firewalld service to use new system configurations.
systemctl restart firewalld
firewall-cmd --state && firewall-cmd --list-all # Show what's enabled in firewalld

# Start stopped services.
if [[ $orchestratorType -eq 1 ]]; then  # If we have Kubernetes
  systemctl start docker kubelet  # For Kubernetes, we also reset docker.
else
  systemctl start docker
fi

systemctl daemon-reload
systemctl reset-failed

#############################################################################################
#if [[ $orchestratorType -eq 1 ]]; then  # If we have Kubernetes
  #echo "Using kube-iptables-tailer for clearer firewall debugging.."
  # The are problems with this tha need to be addressed..
  # TODO - Check this for updates: https://github.com/box/kube-iptables-tailer/issues/15
  #git clone https://github.com/box/kube-iptables-tailer.git \
  #&& cd kube-iptables-tailer \
  #&& make container \
  #&& chmod +w kube-iptables-tailer && rm -rf kube-iptables-tailer \
  #&& iptables -A CHAIN_NAME -j LOG --log-prefix "KUBERNETES-LOG: "
#fi

echo "Finished"

#######################################################################################

# Troubleshootig:
# If firewalld was updated, you might have go back to your user with "CTRL + D" and run "sudo firewall-cmd --state" to have the firewalld authenticated by your user too (since your user will be connected though Ansible).
## If the worker container cannot connect with the master, try this command on the master-node, it should fix the problem:
# sudo systemctl restart firewalld
# TODO - Find a way so this is not needed or to be done automatically..
      # -This is done automatically in the start-services roles, but sometimes there's need for re-doing it.
