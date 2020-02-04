#!/usr/bin/env bash

cd "${0%/*}" || (echo "Could not chdir to this script's working-dir!" && exit)  # Change to current working directory, when running from another location.

# Key-Value Store
EXAREME_KEYSTORE="exareme-keystore:8500"

# Docker internal folder for the Exareme data
DOCKER_DATA_FOLDER="/root/exareme/data/"

FEDERATION_ROLE="master"

flag=0
#Check if data_path exist
if [[ -s data_path.txt ]]; then
    :
else
    echo "What is the data_path for host machine?"
    read answer
    #Check that path ends with /
    if [[ "${answer: -1}"  != "/" ]]; then
            answer=${answer}"/"
    fi
    echo LOCAL_DATA_FOLDER=${answer} > data_path.txt
fi

LOCAL_DATA_FOLDER=$(cat data_path.txt | cut -d '=' -f 2)


chmod 755 *.sh

#Check if Exareme docker image exists in file
if [[ -s ../../Federated-Deployment/Docker-Ansible/group_vars/exareme.yaml ]]; then
    :
else
    . ./../exareme.sh
fi


# If Kubernetes is initialized, reset it.
sudo kubectl get componentstatuses
if [[ $? -eq 0 ]]; then
  echo -e "\nKubernetes was found initialized, resetting..\n"
  sudo bash -c 'chmod +w kubeFiles && rm -rf kubeFiles; kubeadm reset --force && rm -rf $HOME/.kube/config'
fi

echo -e "\nInitializing Kubernetes..\n"
sudo bash -c 'kubeadm init --kubernetes-version=stable --pod-network-cidr=192.168.0.0/16
  (mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config)
  kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml'


echo -e "\nSetting up storageClass..\n"
sudo bash -c '[ ! -d "rook/" ] && git clone --single-branch --branch release-0.8 https://github.com/rook/rook.git
    ; cd rook/cluster/examples/kubernetes/ceph
    && kubectl create -f operator.yaml && kubectl create -f cluster.yaml && kubectl create -f filesystem.yaml && kubectl create -f storageclass.yaml' \
    && sudo kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


#Get hostname of node
name=$(hostname)
#. in hostname gives errors, replace with _
name=${name//./_}

#Get node Hostname
nodeHostname=$(sudo kubectl get nodes -o json | jq --join-output '.items[] | select(.metadata.labels."node-role.kubernetes.io\/master") | .metadata.name')

echo -e "\nUpdate label name and role for Kubernetes node: "${nodeHostname}
sudo kubectl label nodes ${nodeHostname} name=${nodeHostname} && sudo kubectl label nodes ${nodeHostname} role=master
echo -e "\n"

#Read image from file exareme.yaml
image=""
while read -r line  ; do
    if [[ ${line:0:1} == "#" ]] || [[ -z ${line} ]] ; then  #comment line or empty line, continue
        continue
    fi

    image=$(echo ${image})$(echo "$line" | cut -d ':' -d ' ' -d '"' -f 2 -d '"')":"

done < ../../Federated-Deployment/Docker-Ansible/group_vars/exareme.yaml

#remove the last : from string
image=${image:0:-1}

#imageName the first half of string image
imageName=$(echo "$image" | cut -d ':' -f 1)

#tag the second half of string image
tag=$(echo "$image" | cut -d ':' -f 2 )


# Create "default" service-account
sudo kubectl create sa default

# Un-taint master-node, make it ready for scheduling.
sudo kubectl taint nodes ${nodeHostname} node-role.kubernetes.io/master-

mkdir kubeFiles || :
cd kubeFiles || (echo -e "\nCould not 'cd' to 'kubeFiles'-dir!\n" ; exit 1)

# Deploy exareme on the Kubernetes cluster.
sudo env FEDERATION_NODE=${name} FEDERATION_ROLE=${FEDERATION_ROLE} EXAREME_IMAGE=${imageName}":"${tag} \
EXAREME_KEYSTORE=${EXAREME_KEYSTORE} DOCKER_DATA_FOLDER=${DOCKER_DATA_FOLDER} \
LOCAL_DATA_FOLDER=${LOCAL_DATA_FOLDER} \
kompose convert -f ../docker-kompose-master.yml

# TODO - Until kompose v.1.21 comes out with the option to save the produced kubeFiles (as requested here: https://github.com/kubernetes/kompose/issues/1179),
#  keep the < kompose convert --> kubectl create > approach for development..

## Deploy Persistent Volume Claim
# Pre-process it. (some say it should be "ReadWriteMany", although this means that many nodes will write in the same volume, which I don't think is what we want..)
  #sudo chmod +w exareme-master-claim0-persistentvolumeclaim.yaml
  #sudo sed 's/ReadWriteOnce/ReadWriteMany/g' exareme-master-claim0-persistentvolumeclaim.yaml
# Deploy it.
sudo kubectl create -f exareme-master-claim0-persistentvolumeclaim.yaml

# Deploy services
sudo kubectl create -f exareme-keystore-service.yaml \
&& sudo kubectl create -f exareme-master-service.yaml

# Deploy pods
sudo kubectl create -f exareme-keystore-pod.yaml \
&& sudo kubectl create -f exareme-master-pod.yaml

cd ../


#Kubernetes Dashboard
echo -e "\nDo you wish to run Kubernetes-Dashboard?  [ y/n ]"
read answer

while true
do
    if [[ ${answer} == "y" ]]; then
      echo -e "\nInitializing Kubernetes Dashboard..\n"
      sudo kubectl create -f dashboard-admin.yaml # Create admin user.
      sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc3/aio/deploy/recommended.yaml

      # Open a new terminal and let it serve Kubernetes on localhost.. so that we can access the Kubernetes-Dashboard.
      gnome-terminal -e "sudo kubectl proxy"
      if [[ $? -ne 0 ]]; then
        echo -e "\nFailed to open a new terminal to serve Kubernetes proxy on localhost.. in order to acces the Kubernetes-Dashboard!\n"
        break
      fi

      # Wait some time to enter the password in the new terminal and lew the Dashboard to run on localhost.
      echo "Waiting some time to enter the password in the new terminal and let the Dashboard to run on localhost.."
      sleep 13

      # Back here, lets find the token needed to connect to the Dashboard..
      sudo kubectl -n kubernetes-dashboard describe secret $(sudo kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')

      echo -e "\nUse the token above to access the Dashboard in the page opened in your browser.\n"

      # Open prefeared browser to access the Dashboard.
      xdg-open http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

      break # Break out of the loop to finish..
    elif [[ ${answer} == "n" ]]; then
      break
    else
      echo ${answer}" is not a valid answer. Please try again [ y/n ]"
      read answer
    fi
done

echo -e "\nTerminating the script.."
