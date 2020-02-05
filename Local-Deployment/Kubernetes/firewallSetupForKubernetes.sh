#!/bin/bash

# In order not to write the password each time (when using "sudo" for each command)..
# Do a "sudo -i" and then navigate to the path in which this script exists and execute it.

systemctl stop firewalld
systemctl disable firewalld

echo "Setting Firewall-service"
apt install -y firewalld

systemctl enable firewalld
systemctl start firewalld
firewall-cmd --state

echo "Setting Firewallrules for Docker"
firewall-cmd --permanent --add-port=2376/tcp
firewall-cmd --permanent --add-port=2377/tcp && # Add this here -without any argument-condition-, since in local-deploy, kubernetes is running only on master.
firewall-cmd --permanent --add-port=7946/tcp &&
firewall-cmd --permanent --add-port=7946/udp &&
firewall-cmd --permanent --add-port=4987/udp &&
firewall-cmd --permanent --add-port=80/tcp &&
firewall-cmd --permanent --add-port=4789/udp &&
firewall-cmd --permanent --add-port=9000/tcp &&
firewall-cmd --permanent --add-port=8500/tcp &&
firewall-cmd --zone=public --permanent --add-rich-rule='rule protocol value="esp" accept' &&
systemctl restart docker

echo "Setting Firewallrules for Kubernetes"
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379/tcp
firewall-cmd --permanent --add-port=2380/tcp
firewall-cmd --permanent --add-port=10248/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp
firewall-cmd --permanent --add-port=8080/tcp	# For the Kubernetes-Dashboard

firewall-cmd --permanent --add-port=22/tcp	# Allow SSH : Important to not lose remote acces to the VMs!
firewall-cmd --reload && systemctl restart firewalld

echo "Enable br filtering"
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

sysctl -w net.ipv4.ip_forward=1 && sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sysctl -p /etc/sysctl.conf 	# Enable 

swapoff -a && sed -i '2s/^/#/' /etc/fstab	# Turn off swap (for Kubernetes)

echo "Finished"
