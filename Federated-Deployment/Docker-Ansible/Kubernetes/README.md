# Deploy exareme on Kubernetes in federation mode.

## Install requirements
Run the following scripts in all of the machines, to setup the kubernetes-cluster:
- Run **`sudo ./scripts/installRequirements.sh <arg>`**.
    - `<arg>` (clusterMemberType): **1** for master, any other number for a worker
- Run **`sudo ./scripts/firewallSetup.sh <arg1> <arg2> <arg3>`**.
  - `<arg1>` (clusterMemberType): **1** for master, any other number for a worker
  - `<arg2>` (resetMode): **1** for hard-rest, any other number for soft-reset
  - `<arg3>` (orchestratorType): **1** for "Kubernetes", other number for "Docker Swarm"
<br/>

## Other requirements
Click [here](https://github.com/LSmyrnaios/exareme/blob/kubernetes/Federated-Deployment/Documentation/Optionals.md)
for instructions on how to initialize the required files and datasets.<br/>
<br/>
**Note** that the "**Portainer**", which is used in the "Swarm"-mode, does not support Kubernetes.<br/>
The [Kubernetes-Dashboard](https://github.com/kubernetes/dashboard) may be used in the future.
It's currently used only in [local Kubernetes deployment](https://github.com/LSmyrnaios/exareme/tree/kubernetes/Local-Deployment/Kubernetes)<br/>
Ignore also the "**Deployment**" instructions and use the ones below.<br/>
<br/>

## Deployment
In order to deploy **EXAREME** on Kubernetes, run **`./scripts/deploy.sh`** and select the **first** (1) option.<br/>
In case you choose another option, you will be prompted to provide any information needed.<br/>
<br/>

## Test deployment
In order to test your deployment, type ```sudo kubectl get pods -o wide``` in the master node and check all the **pods** are running.
Note that it may take a few minutes for the pods to run smoothly all together.<br/>

Then, find the master-pod's <LAN IP address> by running ```sudo kubectl get pods -o wide | grep 'master'``` in the terminal of your master node.<br/>
You can now open the browser of your master's machine and go to ```http://<master's LAN IP address>:9090/exa-view/index.html```.<br/>
There, you can check that all nodes and datasets are seen by exareme, by scrolling-down and clicking on "**List Datasets**".<br/>

You can also check the technical information about your nodes and datasets by running ```sudo kubectl get pods -o wide | grep 'keystore'``` and
taking the <LAN IP address> of the **keystore**-pod.<br/>
Then, with a browser in your master's machine, go to ```http://<keystore's LAN IP address>/ui/#/dc1/kv/``` and check everything is up and running.<br/>
