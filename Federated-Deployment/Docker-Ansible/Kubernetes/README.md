# Deploy exareme on Kubernetes in federation mode.

## Install requirements
Run the following scripts in all of the machines, to setup the kubernetes-cluster:
- Run **`sudo ./scripts/installRequirements.sh <arg>`**.
    - `<arg>`: **1** for master, any other number for a worker
- Run **`sudo ./scripts/firewallSetupForKubernetes.sh <arg1> <arg2>`**.
  - `<arg1>`: **1** for master, any other number for a worker
  - `<arg2>`: **1** for hard-rest, any other number for soft-reset
<br/>

## Other requirements
Check [here](https://github.com/LSmyrnaios/exareme/blob/kubernetes/Federated-Deployment/README.md) for information.<br/>
Ignore the "**Portainer**" instructions, it does not support Kubernetes. The [Kubernetes-Dashboard](https://github.com/kubernetes/dashboard) may be used in the future.<br/>
Ignore also the "**Deployment**" instructions, use the ones below.<br/>
<br/>

# Deployment
In order to deploy **EXAREME** on Kubernetes run **`./scripts/deploy.sh`** and select the **first** option (1).<br/>
In case you choose another option, you will be prompted to provide any information needed.<br/>