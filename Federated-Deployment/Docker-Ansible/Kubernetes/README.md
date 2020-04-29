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
Click [here](https://github.com/LSmyrnaios/exareme/blob/kubernetes/Federated-Deployment/Documentation/Optionals.md)
for instructions on how to initialize the required files and datasets.<br/>
<br/>
**Note** that the "**Portainer**", which is used in the "Swarm"-mode, does not support Kubernetes.<br/>
The [Kubernetes-Dashboard](https://github.com/kubernetes/dashboard) may be used in the future.
It's currently used only in [local Kubernetes deployment](https://github.com/LSmyrnaios/exareme/tree/kubernetes/Local-Deployment/Kubernetes)<br/>
Ignore also the "**Deployment**" instructions, use the ones below.<br/>
<br/>

# Deployment
In order to deploy **EXAREME** on Kubernetes run **`./scripts/deploy.sh`** and select the **first** (1) option.<br/>
In case you choose another option, you will be prompted to provide any information needed.<br/>