#!/usr/bin/env bash
# TODO (not critical) create function for encryption Process

# Check if vault_pass file exists.
# If it doesn't ask the user to provide it.
# If the user doesn't want to, add the --ask-vault-pass parameter to the ansible calls.
get_vault_authentication () {
	if [[ -s $(sudo find ~/.vault_pass.txt) ]]; then
		echo -e "\nAn ansible password exists in the vault_pass file. Moving on..."
		ansible_vault_authentication="--vault-password-file ~/.vault_pass.txt "
		ansible_playbook+="--vault-password-file ~/.vault_pass.txt "
	else
		echo -e "\nIn order for the installation scripts to run an ansible vault file needs to be created. /
		Do you want to store your Ansible Vault Password in a text file, so that it's not required every time?[ y/n ]"
		read answer
		while true
		do
			if [[ "${answer}" == "y" ]]; then
				echo "Type your Ansible password:"
				read -s password
				echo $password > ~/.vault_pass.txt
				ansible_playbook+="--vault-password-file ~/.vault_pass.txt "

				# For encrypting/ decrypting vault.yaml file
				ansible_vault_authentication="--vault-password-file ~/.vault_pass.txt "
				break
			elif [[ "${answer}" == "n" ]]; then
				echo "You need to enter your Ansible password every single time ansible-playbooks asks for one."
				sleep 1
				ansible_playbook+="--ask-vault-pass "

				#For encrypting/ decrypting vault.yaml file
				ansible_vault_authentication="--ask-vault-pass "
				break
			else
				echo "$answer is not a valid answer! Try again.. [ y/n ]"
				read answer
			fi
		done
	fi
}

# Information for username/password for hosts.ini & vault.yaml files
usernamePassword () {
	echo -e "\n"${1}" remote_user=\"{{"${1}"_remote_user}}\"" >> ../hosts.ini
	echo ${1}" become_user=\"{{"${1}"_become_user}}\"" >> ../hosts.ini
	echo ${1}" ansible_become_pass=\"{{"${1}"_become_pass}}\"" >> ../hosts.ini
	echo -e ${1}" ansible_ssh_pass=\"{{"${1}"_ssh_pass}}\"\n" >> ../hosts.ini
}

checkIP () {

    while true
	do
		if [[ ${1} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
			for i in 1 2 3 4; do
				if [[ $(echo "$1" | cut -d. -f$i) -gt 255 ]]; then
					echo "$1" | cut -d. -f$i
					echo -e "\n${1} is not a valid IP. Try again.."
					read answer
				fi
			done
			break
		else
			echo -e "\n${1} is not a valid IP. Try again.."
			read answer
		fi
	done

}
# Get Worker Node Info
workerHostsInfo () {
	echo -e "\nWhat is the ansible host for target \"${1}\"? (expecting IP)"
	read answer

	checkIP ${answer}

	echo -e "\n[${1}]" >> ../hosts.ini
	echo ${1} "ansible_host="${answer} >> ../hosts.ini

	echo -e "\nWhat is the hostname for target \"${1}\"?"
	read answer
	echo ${1} "hostname="${answer} >> ../hosts.ini

	echo -e "\nWhat is the data_path for target \"${1}\"?"
	read answer
	#Check that path ends with /
	if [[ "${answer: -1}"  != "/" ]]; then
			answer=${answer}"/"
	fi
	echo ${1} "data_path="${answer} >> ../hosts.ini

	usernamePassword ${1}
}

# Get Master Node Info
masterHostsInfo () {
    echo -e "\nWhat is the ansible host for target \"master\"? (expecting IP)"
    read answer

    checkIP ${answer}

    echo "master ansible_host="${answer} >> ../hosts.ini
    echo -e "\nWhat is the home path for target \"master\"?"
    read answer
    #Check that path ends with /
    if [[ "${answer: -1}"  != "/" ]]; then
        answer=${answer}"/"
    fi
    echo "master home_path="${answer} >> ../hosts.ini

    echo -e "\nWhat is the data path for targer \"master\"?"
    read answer
    #Check that path ends with /
    if [[ "${answer: -1}"  != "/" ]]; then
        answer=${answer}"/"
    fi
    echo "master data_path="${answer} >> ../hosts.ini
    usernamePassword "master"
}

# Get master Vault Info
masterVaultInfos () {

    echo -e "\nWhat is the remote user for target \"master\"?"
    read remote_user
    master_remote_user="master_remote_user: "${remote_user}


    echo -e "\nWhat is the password for remote user:\"${remote_user}\" for target \"master\"?"
    read -s remote_pass

    echo -e "\nWhat is the become user for target \"master\"? (root if possible)"
    read become_user
    master_become_user="master_become_user: "${become_user}

    echo -e "\nWhat is the password for become user:\"${become_user}\" for target \"master\"?"
    read -s become_pass

    master_ssh_pass="master_ssh_pass: "${remote_pass}
    master_become_pass="master_become_pass: "${become_pass}

}

# Get Worker Vault Info
workerVaultInfos () {

    echo -e "\nWhat is the remote user for target \"${1}\"?"
    read remote_user
    var_remote_user=${1}"_remote_user: "${remote_user}

    echo -e "\nWhat is the password for remote user:\"${remote_user}\" for target \"${1}\"?"
    read -s remote_pass

    echo -e "\nWhat is the become user for target \"${1}\"? (root if possible)"
    read become_user
    var_become_user=${1}"_become_user: "${become_user}

    echo -e "\nWhat is the password for become user:\"${become_user}\" for target \"${1}\"?"
    read -s become_pass

    ssh_pass=${1}"_ssh_pass: "${remote_pass}
    become_pass=${1}"_become_pass: "${become_pass}
}

#Write master's target node vault Information
writeMastersVaultInfo () {

    # Vault Information for target Master
    echo -e "\nVault Information for master target machine are needed (vault.yaml)."
    masterVaultInfos

    echo ${master_remote_user} >> ../vault.yaml
    echo ${master_become_user} >> ../vault.yaml
    echo ${master_ssh_pass} >> ../vault.yaml
    echo ${master_become_pass} >> ../vault.yaml

    ansible_vault_encrypt="ansible-vault encrypt ../vault.yaml "${ansible_vault_authentication}    #--vault-password-file or --ask-vault-pass depending if  ~/.vault_pass.txt exists
    ${ansible_vault_encrypt}

    ansible_playbook_code=$?
    # If status code != 0 an error has occurred
    if [[ ${ansible_playbook_code} -ne 0 ]]; then
        echo "Encryption of file \"../vault.yaml\" exited with error. Removing file with sensitive information. Exiting.." >&2
        rm -rf ../vault.yaml
        exit 1
    fi

}

#Write workers target node vault Information
writeWorkersVaultInfo () {

    workerVaultInfos "worker"${1}

    # TODO (not critical) decrypt encrypt only once with dynamic variables
    ansible_vault_decrypt="ansible-vault decrypt ../vault.yaml "${ansible_vault_authentication}    #--vault-password-file or --ask-vault-pass depending if  ~/.vault_pass.txt exists
    ${ansible_vault_decrypt}

    ansible_playbook_code=$?
    # If status code != 0 an error has occurred
    if [[ ${ansible_playbook_code} -ne 0 ]]; then
        echo "Decryption of file \"../vault.yaml\" exited with error.Exiting.." >&2
        exit 1
    fi

    echo -e "\n" >> ../vault.yaml
    echo ${var_remote_user} >> ../vault.yaml
    echo ${var_become_user} >> ../vault.yaml
    echo ${ssh_pass} >> ../vault.yaml
    echo ${become_pass} >> ../vault.yaml

    ansible_vault_encrypt="ansible-vault encrypt ../vault.yaml "${ansible_vault_authentication}    #--vault-password-file or --ask-vault-pass depending if  ~/.vault_pass.txt exists
    ${ansible_vault_encrypt}

    ansible_playbook_code=$?
    # If status code != 0 an error has occurred
    if [[ ${ansible_playbook_code} -ne 0 ]]; then
        echo "Encryption of file \"../vault.yaml\" exited with error. Removing file with sensitive information. Exiting.." >&2
        rm -rf ../vault.yaml
        exit 1
    fi

}

# (Re)Initialize hosts.ini file
createFiles () {

    # Information for target Master
    echo -e "\nInformation for master target machine are needed (hosts.ini)."
    echo "[master]" >> ../hosts.ini
    masterHostsInfo

    writeMastersVaultInfo

    echo -e "\nAre there any target \"worker\" nodes? [ y/n ]"
    read answer

    while true
    do
        if [[ ${answer} == "y" ]]; then
            echo -e "\nHow many target \"worker\" nodes are there?"
            read answer1
            #Check if what was given is a number
            while true
            do
                if ! [[ "$answer1" =~ ^[0-9]+$ ]]; then
                    echo "${answer1} is not a valid number! Try again.."
                    read answer1
                else
                    break
                fi
            done

            echo "[workers]" >> ../hosts.ini

            worker=1
            #Construct worker88.197.53.38, worker88.197.53.44 .. workerN below [workers] tag
            while [[ ${answer1} != 0 ]]
            do
                echo -e "\nWhat is the IP of the ${worker}st worker node?"
                read answer
                checkIP ${answer}

                echo "worker"${answer} >> ../hosts.ini
                worker=$[${worker}+1]
                answer1=$[${answer1}-1]
            done

            #For each worker1, worker2, .. workerN place infos in hosts.ini
            worker=$[${worker}-1]
            n=1
            while [[ ${worker} != 0 ]]
            do
                echo -e "\nInformation for workers target machines' are needed (hosts.ini).."
                workerHostsInfo "worker"${n}

                echo -e "\nVault Information for workers target machines' are needed (vault.yaml).."
                writeWorkersVaultInfo ${n}

                n=$[${n}+1]
                worker=$[${worker}-1]
            done
            break

        elif [[ ${answer} == "n" ]]; then
            break
        else
            echo "${answer} is not a valid answer! Try again.. [ y/n ]"
            read answer
        fi
    done

}


# If include-only flag is given don't execute the script
if [[ "$1" == "include-only" ]]; then
  return
fi


# Remove file if it already exists
if [[ -s ../hosts.ini ]]; then
    rm -f ../hosts.ini
fi

# Remove file if it already exists
if [[ -s ../vault.yaml ]]; then
    rm -f ../vault.yaml
fi

createFiles
