#!/usr/bin/env bash
# Key-Value Store
EXAREME_KEYSTORE="exareme-keystore:8500"

# Docker internal folder for the Exareme data
DOCKER_DATA_FOLDER="/root/exareme/data/"

# Portainer
PORTAINER_PORT="9000"
PORTAINER_IMAGE="portainer/portainer"
PORTAINER_VERSION=":latest"
PORTAINER_DATA=$(echo $PWD)"/portainer"
PORTAINER_NAME="mip_portainer"

FEDERATION_ROLE="master"

PUBLIC_IP="127.0.0.1"
LOCAL_IP="127.0.0.1"

_get_public_ip(){
	ip=$(wget http://ipinfo.io/ip -qO -)
	if [ "$ip" != "" ]; then
		PUBLIC_IP=$ip
	fi
}

_get_local_ip(){
	local iface=$(ip route show|awk '/^default via/ {print $NF" "$5}'|sort|head -1|cut -d ' ' -f 2)
	local ip=$(ip address show|grep "inet.*$iface"|awk '{print $2}'|cut -d '/' -f1)
	if [ "$ip" != "" ]; then
		LOCAL_IP=$ip
	fi
}

_get_public_ip
_get_local_ip

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

. ./data_path.txt

#Run convert-csv-to-db
chmod 775 ../Exareme-Docker/files/root/exareme/convert-csv-dataset-to-db.py
#Removing all previous .db files from the LOCAL_DATA_FOLDER
echo "Starting the process of creating databases.."
echo -e "\nDeleting previous databases."
rm -rf ${LOCAL_DATA_FOLDER}/**/*.db

echo -e "\nParsing csv files in " ${LOCAL_DATA_FOLDER} " to database files. "
python ../Exareme-Docker/files/root/exareme/convert-csv-dataset-to-db.py -f ${LOCAL_DATA_FOLDER} -t "master"
#Get the status code from previous command
py_script=$?
#If status code != 0 an error has occurred
if [[ ${py_script} -ne 0 ]]; then
     echo -e "\nCreation of databases failed. Exareme will not run until fixes be made." >&2
     exit 1
fi

chmod 755 *.sh

#Check if Exareme docker image exists in file
if [[ -s exareme.yaml ]]; then
    :
else
    . ./exareme.sh
fi

#Previous Swarm not found
if [[ $(sudo docker info | grep Swarm | grep inactive*) != '' ]]; then
    echo -e "\nInitialize Swarm.."
    sudo docker swarm init --advertise-addr=${LOCAL_IP}
#Previous Swarm found
else
    echo -e "\nLeaving previous Swarm.."
    sudo docker swarm leave -f
    sleep 1
    echo -e "\nInitialize Swarm.."
    sudo docker swarm init --advertise-addr=${LOCAL_IP}
fi

#Init network
if [[ $(sudo docker network ls | grep mip-local) == '' ]]; then
    echo -e "\nInitialize Network"
    sudo docker network create \
            --driver=overlay --opt encrypted  --subnet=10.20.30.0/24  --ip-range=10.20.30.0/24 --gateway=10.20.30.254 mip-local
fi

#Get hostname of node
name=$(hostname)
#. if hostname gives errors, replace with _
name=${name//./_}

#Get node Hostname
nodeHostname=$(sudo docker node ls --format {{.Hostname}})

echo -e "\nUpdate label name for Swarm node "${nodeHostname}
sudo docker node update --label-add name=${name} ${nodeHostname}
echo -e "\n"

#Read image from file exareme.yaml
image=""
while read -r line  ; do
    if [[ ${line:0:1} == "#" ]] || [[ -z ${line} ]] ; then  #comment line or empty line, continue
        continue
    fi

    image=$(echo ${image})$(echo "$line" | cut -d ':' -d ' ' -d '"' -f 2 -d '"')":"

done < exareme.yaml

#remove the last : from string
image=${image:0:-1}

#imageName the first half of string image
imageName=$(echo "$image" | cut -d ':' -f 1)

#tag the second half of string image
tag=$(echo "$image" | cut -d ':' -f 2 )

#Stack deploy
sudo env FEDERATION_NODE=${name} FEDERATION_ROLE=${FEDERATION_ROLE} EXAREME_IMAGE=${imageName}":"${tag} \
EXAREME_KEYSTORE=${EXAREME_KEYSTORE} DOCKER_DATA_FOLDER=${DOCKER_DATA_FOLDER} \
LOCAL_DATA_FOLDER=${LOCAL_DATA_FOLDER} \
docker stack deploy -c docker-compose-master.yml ${name}

#Portainer
echo -e "\nDo you wish to run Portainer? [ y/n ]"
read answer

while true

do
    if [[ ${answer} == "y" ]]; then
    echo -e "\nDo you wish to run Portainer in a Secure way? (SSL certificate required)  [ y/n ]"
    read answer

    while true
    do
        if [[ ${answer} == "y" ]];then
            if [[ -s domain_name.txt ]]; then
                . ./domain_name.txt
                #Run Secure Portainer service
                flag=1
                command=$(sudo find /etc/letsencrypt/live/${DOMAIN_NAME}/cert.pem 2> /dev/null)
                if [[ ${command} == "/etc/letsencrypt/live/"${DOMAIN_NAME}"/cert.pem" ]]; then
                    . ./portainer.sh
                else
                    echo -e "\nNo certificate for the Domain name: "${DOMAIN_NAME}" existing in file \"domain_name.txt\". Starting without Portainer.."
                fi
            else
                echo -e "\nWhat is the Domain name for which an SSL certificate created?"
                read answer
                command=$(sudo find /etc/letsencrypt/live/${answer}/cert.pem 2> /dev/null)

                if [[ ${command} == "/etc/letsencrypt/live/"${answer}"/cert.pem" ]]; then
                    DOMAIN_NAME=${answer}

                    #Optional to store Domain_name in a file
                    echo -e "\nDo you wish that Domain name to be stored so you will not be asked again? [y/n]"
                    read answer
                    while true
                    do
                        if [[ ${answer} == "y" ]]; then
                            echo "Storing information.."
                            echo DOMAIN_NAME=${DOMAIN_NAME} > domain_name.txt
                            break
                        elif [[ ${answer} == "n" ]]; then
                            echo "You will be asked again to provide the domain name.."
                            break
                        else
                            echo "$answer is not a valid answer! Try again.. [ y/n ]"
                            read answer
                        fi
                    done

                    #Run Secure Portainer service
                    flag=1
                    . ./portainer.sh
                else
                    echo -e "\nNo certificate for that Domain name: "${answer}". Starting without Portainer.."
                fi
            fi
            break
        elif [[ ${answer} == "n" ]]; then
            flag=0
            . ./portainer.sh
            break
        else
            echo ${answer}" is not a valid answer. Try again [ y/n ]"
            read answer
        fi
    done
    elif [[ ${answer} == "n" ]]; then
        :
    else
        echo ${answer}" is not a valid answer. Try again [ y/n ]"
        read answer
    fi
    break
done