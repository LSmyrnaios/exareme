# Deploy exareme on Kubernetes in federation mode.

## Install requirements
Run the following scripts in all of the machines, to setup the kubernetes-cluster:
- Run `sudo ./installRequirements.sh <arg>`.
    - `<arg>`: **1** for master, any other number for a worker
- Run `sudo ./firewallSetupForKubernetes.sh <arg1> <arg2>`.
  - `<arg1>`: **1** for master, any other number for a worker
  - `<arg2>`: **1** for hard-rest, any other number for soft-reset

## Other requirements
Check [here](https://github.com/LSmyrnaios/exareme/blob/kubernetes/Federated-Deployment/README.md) for information.


# Deployment
In the ```Federated-Deployment/Docker-Ansible/Kubernetes/scripts``` directory, run the ```deployLocal.sh``` to start the deployment.
You will be prompted to provide any information needed.