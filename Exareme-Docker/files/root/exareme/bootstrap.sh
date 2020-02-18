#!/usr/bin/env bash

if [[ -z "${EXAREME_ACTIVE_WORKERS_PATH}" ]]; then
	echo "Env. variable 'active_workers' not initialized in docker-compose.yaml files. Exiting..."
	exit 1
fi

if [[ -z "${EXAREME_MASTER_PATH}" ]]; then
	echo "Env. variable 'master' not initialized in docker-compose.yaml files. Exiting..."
	exit 1
fi

if [[ -z "${DATA}" ]]; then
	echo "Env. variable 'data' not initialized in docker-compose.yaml files. Exiting..."
	exit 1
fi
if [[ -z ${CONSULURL} ]]; then echo "CONSULURL is unset"; exit; fi
if [[ -z ${NODE_NAME} ]]; then echo "NODE_NAME is unset";exit;  fi
if [[ -z ${DOCKER_DATA_FOLDER} ]]; then echo "DOCKER_DATA_FOLDER is unset"; exit; fi

#Stop Exareme service
stop_exareme () {
	if [[ -f /tmp/exareme/var/run/*.pid ]]; then
		kill -9 $( cat /tmp/exareme/var/run/*.pid)
		rm /tmp/exareme/var/run/*.pid
		echo "Stopped."
		exit 0
	else
	   echo "Already stopped, no action taken."
	fi
}

#Clean ups in Consul [key-value store]
deleteKeysFromConsul () {
	if [[ "$(curl -s -o  /dev/null -i -w "%{http_code}\n" ${CONSULURL}/v1/kv/${DATA}/${NODE_NAME}?keys)" = "200" ]]; then
		curl -s -X DELETE $CONSULURL/v1/kv/$DATASETS/$NODE_NAME
	fi
	if [[ "$(curl -s -o  /dev/null -i -w "%{http_code}\n" ${CONSULURL}/v1/kv/${1}/${NODE_NAME}?keys)" = "200" ]]; then
		curl -s -X DELETE $CONSULURL/v1/kv/$1/$NODE_NAME
	fi
}

#CSVs to DB
transformCsvToDB () {
	# Both Master and Worker should transform the csvs to sqlite db files
	# Removing all previous .db files from the DOCKER_DATA_FOLDER
	echo "Deleting previous db files. "
	rm -rf ${DOCKER_DATA_FOLDER}/**/*.db
	
	echo "Parsing the csv files in " ${DOCKER_DATA_FOLDER} " to db files. "
	python ./convert-csv-dataset-to-db.py -f ${DOCKER_DATA_FOLDER} -t ${1}
	#Get the status code from previous command
	py_script=$?
	#If status code != 0 an error has occurred
	if [[ ${py_script} -ne 0 ]]; then
		 echo "Script: \"convert-csv-dataset-to-db.py\" exited with error." >&2
		 exit 1
	fi
}

# Setup signal handlers
trap term_handler SIGTERM SIGKILL

#This funciton will be executed when the container receives the SIGTERM signal (when stopping)
term_handler () {

if [[ "${MASTER_FLAG}" != "master" ]]; then   #worker
	echo "*******************************Stopping Worker**************************************"
	if [[ "$(curl -s ${CONSULURL}/v1/health/state/passing | jq -r '.[].Status')" = "passing" ]];  then
		deleteKeysFromConsul "$EXAREME_ACTIVE_WORKERS_PATH"
	fi
	if [[ "$(curl -s -o  /dev/null -i -w "%{http_code}\n" ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/?keys)" = "200" ]]; then
		MY_IP=$(/sbin/ifconfig eth0 | grep "inet" | awk -F: '{print $2}' | cut -d ' ' -f 1)
		MASTER_IP=$(curl -s ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/$(curl -s ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/?keys | jq -r '.[]' | sed "s/${EXAREME_MASTER_PATH}\///g")?raw)
		#Delete worker from master's registry
		curl -s ${MASTER_IP}:9091/remove/worker?IP=${MY_IP}		#TODO check if that was done?
	fi
	stop_exareme
else									  #master
	echo "*******************************Stopping Master**************************************"
	if [[ "$(curl -s ${CONSULURL}/v1/health/state/passing | jq -r '.[].Status')" = "passing" ]];  then
		deleteKeysFromConsul "$EXAREME_MASTER_PATH"
	fi
	stop_exareme
fi
exit 0
}

mkdir -p  /tmp/demo/db/

#This is the Worker
if [[ "${MASTER_FLAG}" != "master" ]]; then

	DESC="exareme-worker"
	MY_IP=$(/sbin/ifconfig eth0 | grep "inet" | awk -F: '{print $2}' | cut -d ' ' -f 1)

	#Try accessing Consul[key-value store]
	echo -e "\nWorker node["${NODE_NAME}","${MY_IP}"] trying to connect with Consul[key-value store]"
	n=0
	#Wait until Consul [key-value store] is up and running
	while [[ "$(curl -s ${CONSULURL}/v1/health/state/passing | jq -r '.[].Status')" != "passing" ]]; do
		echo -e "\nWorker node["${NODE_NAME}","${MY_IP}"] trying to connect with Consul[key-value store]"
		sleep 2
		n=$((${n} + 1))
		#After 4 attempts-Show error
		if [[ ${n} -ge 5 ]]; then
			echo -e "\nConsul[key-value store] may not be initialized or Worker node["${NODE_NAME}","${MY_IP}"] can not contact Consul[key-value store]"
			exit 1  #Simple exit 1. Exareme is not up yet
		fi
	done

	#Try retrieve Master's IP from Consul[key-value store]
	echo -e "Retrieving Master's info from Consul[key-value store]"
	n=0
	while [[ "$(curl -s -o  /dev/null -i -w "%{http_code}\n" ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/?keys)" != "200" ]]; do
		sleep 5
		n=$((${n} + 1))
		echo -e "Retrieving Master's info from Consul[key-value store]"
		if [[ ${n} -ge 30 ]]; then
			echo "Is Master node initialized? Check Master's logs. Terminating Worker node["${NODE_NAME}","${MY_IP}"]"
			exit 1
		fi
	done

	#Get Master's IP/Name from Consul[key-value store]
	MASTER_IP=$(curl -s ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/$(curl -s ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/?keys | jq -r '.[]' | sed "s/${EXAREME_MASTER_PATH}\///g")?raw)
	MASTER_NAME=$(curl -s ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/?keys | jq -r '.[]' | sed "s/${EXAREME_MASTER_PATH}\///g")

	#CSVs to DB
	transformCsvToDB "worker"

	. ./start-worker.sh
	echo "Worker node["${MY_IP}","${NODE_NAME}]" trying to connect with Master node["${MASTER_IP}","${MASTER_NAME}"]"
	while [[ ! -f /var/log/exareme.log ]]; do
		echo "Worker node["${MY_IP}","${NODE_NAME}]" trying to connect with Master node["${MASTER_IP}","${MASTER_NAME}"]"
		sleep 1
	done
	echo "Waiting to establish connection for Worker node["${MY_IP}","${NODE_NAME}"] with Master node["${MASTER_IP}","${MASTER_NAME}"]"
	tail -f /var/log/exareme.log | while read LOGLINE
	do
		[[ "${LOGLINE}" == *"Worker node started."* ]] && pkill -P $$ tail
		echo "Waiting to establish connection for Worker node["${MY_IP}","${NODE_NAME}"] with Master node["${MASTER_IP}","${MASTER_NAME}"]"
		sleep 1

		#Java's exception in StartWorker.java
		if [[ "${LOGLINE}" == *"java.rmi.RemoteException"* ]]; then
			exit 1  #Simple exit 1. Exareme is not up yet
		fi
	done

    if [[ ${TAG} == "dev" ]]; then
        echo "Running set-local-datasets."
	    ./set-local-datasets.sh

        echo -e "\nDEV version: Worker node["${MY_IP}","${NODE_NAME}"] may be connected to Master node["${MASTER_IP}","${MASTER_NAME}"]"
        curl -s -X PUT -d @- ${CONSULURL}/v1/kv/${EXAREME_ACTIVE_WORKERS_PATH}/${NODE_NAME} <<< ${MY_IP}
    elif [[ ${TAG} == "prod" ]]; then
        #Health check for Worker. HEALTH_CHECK algorithm execution
        echo "Health check for Worker node["${MY_IP}","${NODE_NAME}"]"

        check="$(curl -s ${MASTER_IP}:9092/check/worker?IP_MASTER=${MASTER_IP}?IP_WORKER=${MY_IP})"

        if [[ -z ${check} ]]; then
            #If curl returned nothing, something is wrong. We can not know what is wrong though..
            printf "Health_Check algorithm did not return anything...Switch TAG to 'dev' to see Error messages coming\
from EXAREME..Exiting"
            exit 1
        else
            #check if what curl returned is JSON
            echo ${check} | jq empty
            #if NOT JSON an error code will be returned (!=0)
            check_code=$?
            if [[ ${check_code} -ne 0 ]]; then
                echo "An error has occurred: " ${check} ".....Exiting"
                exit 1
            else
                getNames="$( echo ${check} | jq '.active_nodes')"

                #Retrieve result as json. If $NODE_NAME exists in result, the algorithm run in the specific node
                if [[ ${getNames} = *${NODE_NAME}* ]]; then
                    echo -e "\nWorker node["${MY_IP}","${NODE_NAME}"] connected to Master node["${MASTER_IP}","${MASTER_NAME}"]"
                    curl -s -X PUT -d @- ${CONSULURL}/v1/kv/${EXAREME_ACTIVE_WORKERS_PATH}/${NODE_NAME} <<< ${MY_IP}

                    echo "Running set-local-datasets."
                    ./set-local-datasets.sh

                else
                    echo ${check}
                    echo "Worker node["${MY_IP}","${NODE_NAME}]" seems that is not connected with the Master..\
Switch TAG to 'dev' to see Error messages coming from EXAREME..Exiting..."
                    exit 1
                fi
            fi
        fi
    fi

#This is the Master
else
	DESC="exareme-master"
	MY_IP=$(/sbin/ifconfig eth0 | grep "inet" | awk -F: '{print $2}' | cut -d ' ' -f 1)

	echo -e "\nMaster node["${NODE_NAME}","${MY_IP}"] trying to connect with Consul[key-value store]"

	#Try accessing Consul[key-value store]
	echo -e "\nMaster node["${NODE_NAME}","${MY_IP}"] trying to connect with Consul[key-value store]"
	n=0
	#Wait until Consul [key-value store] is up and running
	while [[ "$(curl -s ${CONSULURL}/v1/health/state/passing | jq -r '.[].Status')" != "passing" ]]; do
		echo -e "\nMaster node["${NODE_NAME}","${MY_IP}"] trying to connect with Consul[key-value store]"
		n=$((${n} + 1))
		sleep 1
		#After 30 attempts-Show error
		if [[ ${n} -ge 30 ]]; then
			echo -e "\nConsul[key-value store] may not be initialized or Master node["${NODE_NAME}","${MY_IP}"] can not contact Consul[key-value store]"
			exit 1  #Simple exit 1. Exareme is not up yet
		fi
	done

	#CSVs to DB
	transformCsvToDB "master"

	#Master re-booted
	if [[ "$(curl -s -o  /dev/null -i -w "%{http_code}\n" ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/?keys)" = "200" ]]; then
		#Workers connected to Master node
		if [[ "$(curl -s -o  /dev/null -i -w "%{http_code}\n" ${CONSULURL}/v1/kv/${EXAREME_ACTIVE_WORKERS_PATH}/?keys)" = "200" ]]; then
			:
			#TODO check what if master restarts with different IP while workers are already connected to the master's registry with previous IP
		else
			./exareme-admin.sh --start
			echo "Master node["${MY_IP}","$NODE_NAME"] trying to re-boot..."
			while [[ ! -f /var/log/exareme.log ]]; do
				echo "Master node["$MY_IP"," $NODE_NAME"] re-booted..."
			done
		fi

	#Master node just created
	else
		./exareme-admin.sh --start
		echo "Initializing Master node["${MY_IP}","${NODE_NAME}"]"

		while [[ ! -f /var/log/exareme.log ]]; do
			echo "Initializing Master node["${MY_IP}","${NODE_NAME}"]"
		done
		echo "Initializing Master node["${MY_IP}","${NODE_NAME}"]"
		tail -f /var/log/exareme.log | while read LOGLINE
		do
			[[ "${LOGLINE}" == *"Master node started."* ]] && pkill -P $$ tail
			echo "Initializing Master node["${MY_IP}","${NODE_NAME}"]"

			#Java's exception in StartMaster.java
			if [[ "${LOGLINE}" == *"java.rmi.RemoteException"* ]]; then
				exit 1  #Simple exit 1. Exareme is not up yet
			fi
		done
	
        if [[ ${TAG} == "dev" ]]; then
             echo "Running set-local-datasets."
		    ./set-local-datasets.sh

            echo -e "\nDEV version: Master node["${MY_IP}","${NODE_NAME}"] may be initialized"
            curl -s -X PUT -d @- ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/${NODE_NAME} <<< ${MY_IP}
        elif [[ ${TAG} == "prod" ]]; then
		    #Health check for Master. HEALTH_CHECK algorithm execution
		    echo "Health check for Master node["${MY_IP}","${NODE_NAME}"]"

		    check=$(curl -s ${MY_IP}:9092/check/worker?IP_MASTER=${MY_IP}?IP_WORKER=${MY_IP})    #Master has a Worker instance. So in this case IP_MASTER / IP_WORKER is the same

            if [[ -z ${check} ]]; then
            #if curl returned nothing, something is wrong. We can not know what is wrong though
                printf "Health_Check algorithm did not return anything...Switch TAG to 'dev' to see Error messages coming\
from EXAREME..Exiting"
                exit 1
            else
                #check if what curl returned is JSON
                echo ${check} | jq empty
                #if NOT JSON an error code will be returned (!=0)
                check_code=$?
                if [[ ${check_code} -ne 0 ]]; then
                    echo "An error has occurred: " ${check} ".....Exiting"
                    exit 1
                else
                    getNames="$( echo ${check} | jq '.active_nodes')"

                    #Retrieve result as json. If $NODE_NAME exists in result, the algorithm run in the specific node
                    if [[ ${getNames} = *${NODE_NAME}* ]]; then
                        echo -e "\nMaster node["${MY_IP}","${NODE_NAME}"] initialized"
                        curl -s -X PUT -d @- ${CONSULURL}/v1/kv/${EXAREME_MASTER_PATH}/${NODE_NAME} <<< ${MY_IP}

                        echo "Running set-local-datasets."
                        ./set-local-datasets.sh

                    else
                        echo ${check}
                        echo "Master node["${MY_IP}","${NODE_NAME}]" seems that could not be initialized..\
Switch TAG to 'dev' to see Error messages coming from EXAREME..Exiting..."
                        exit 1
                    fi
                fi
            fi
        fi
	fi
fi

echo '*/15  *  *  *  *	./set-local-datasets.sh' >> /etc/crontabs/root
crond

# Creating the python log file
echo "Exareme Python Algorithms log file created." > /var/log/exaremePythonAlgorithms.log

# Running something in foreground, otherwise the container will stop
while true
do
   tail -f /var/log/exareme.log -f /var/log/exaremePythonAlgorithms.log
done
