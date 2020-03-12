#!/usr/bin/env bash

# If include-only flag is given don't execute the script
if [[ "$1" == "include-only" ]]; then
  return
fi

echo -e "\nInitializing kubernetes, initializing mip-federation network, copying Compose-Files folder to Manager of kubernetes..."
sleep 1

# Init_kubernetes
ansible_playbook_init=${ansible_playbook}"../Init-Kubernetes.yaml"
${ansible_playbook_init}

ansible_playbook_code=$?
# If status code != 0 an error has occurred
if [[ ${ansible_playbook_code} -ne 0 ]]; then
    echo "Playbook \"Init-kubernetes.yaml\" exited with error." >&2
    exit 1
fi

# Join_workers
echo -e "\nJoining worker nodes in kubernetes..\n"
while IFS= read -r line; do
    if [[ "$line" = *"[workers]"* ]]; then
        while IFS= read -r line; do
            ansible_playbook_join=${ansible_playbook}"../Join-Workers.yaml -e my_host="
            worker=$(echo "$line")
            if [[ -z "$line" ]]; then
                continue        #If empty line continue..
            fi
            if [[ "$line" = *"["* ]]; then
                break
            fi
            ansible_playbook_join+=${worker}
            flag=0
            ${ansible_playbook_join}

            ansible_playbook_code=$?
            #If status code != 0 an error has occurred
            if [[ ${ansible_playbook_code} -ne 0 ]]; then
                echo "Playbook \"Join-Workers.yaml\" exited with error." >&2
                exit 1
            fi
            echo -e "\n${worker} is now part of the kubernetes..\n"
            sleep 1
        done
    fi
done < ../../hosts.ini
if [[ ${flag} != "0" ]]; then
    echo -e "\nIt seems that no workers will join the kubernetes. If you have workers \
make sure you include them when initializing the exareme kubernetes target machines' information (hosts.ini, vault.yaml)."
    echo -e "\nContinue? [ y/n ]"

    read answer
    while true
    do
        if [[ "${answer}" == "y" ]]; then
            echo "Continuing without Workers.."
            break
        elif [[ "${answer}" == "n" ]]; then
            echo "Exiting...(Leaving kubernetes for Master node).."
            ansible_playbook_leave=${ansible_playbook}"../Leave-Master.yaml"
            ${ansible_playbook_leave}

            ansible_playbook_code=$?
            # If status code != 0 an error has occurred
            if [[ ${ansible_playbook_code} -ne 0 ]]; then
                echo "Playbook \"Leave-Master.yaml\" exited with error." >&2
                exit 1
            fi
            exit 1
        else
            echo "$answer is not a valid answer! Try again.. [ y/n ]"
            read answer
        fi
    done
fi

#Start Exareme
echo -e "\nStarting Exareme services...Do you wish to run Dashboard as well [ y/n ]?"

#read answer
answer=n # TODO - Set it like this for debug! When Dashboard gets ready, get answer from user!
echo "${answer}"

while true
do
    if [[ "${answer}" == "y" ]]; then
        #portainer  # TODO - to be replaced with a dashboard-equivalent.
        break
    elif [[ "${answer}" == "n" ]]; then
        #Run only Exareme, skip portainer and portainerSecure tags
        ansible_playbook_start=${ansible_playbook}"../Start-Exareme.yaml --skip-tags dashboard"
        ${ansible_playbook_start}

        ansible_playbook_code=$?

        #If status code != 0 an error has occurred
        if [[ ${ansible_playbook_code} -ne 0 ]]; then
            echo "Playbook \"Start-Exareme.yaml --skip-tags dashboard\" exited with error." >&2
            exit 1
        fi
        echo -e "\nExareme services are now running"
        break
    else
        echo "$answer is not a valid answer! Try again.. [ y/n ]"
        read answer
    fi
done