# Deploy exareme on Kubernetes locally.

## Install requirements
Run the following scripts to set-up kubernetes:
- Run the script "installRequirements.sh".
- Enter "SuperUser"-mode (`sudo -i`), navigate to this path and run the script "firewallSetupForKubernetes.sh".

## Data structure
Check [here](https://github.com/LSmyrnaios/exareme/blob/kubernetes/Local-Deployment/README.md#data-structure) for information.


## [Optional] Exareme Version
Check [here](https://github.com/LSmyrnaios/exareme/blob/kubernetes/Local-Deployment/README.md#optional-exareme-version) for information.


## [Optional] Data path location
Check [here](https://github.com/LSmyrnaios/exareme/blob/kubernetes/Local-Deployment/README.md#optional-data-path-location) for information.


# Deployment

In the ```Local-Deployment/Kubernetes``` folder, run the ```deployLocal.sh``` to start the deployment.
You will be prompted to provide any information needed.

## Access Kubernetes-Dashboard
If you want to use the Kubernetes-Dashboard you should reply <y> when prompted by the script.<br/>
Then a new terminal will pop-up asking you to enter your password in order for kubernetes to serve on localhost.<br/>
After entering your password, the script will produce a token which you can use to access the Dashboard which will be opened automatically in your preferred browser.<br/>


## Revival from errors

If you encounter any issues with kubernetes, it's maybe because the script was terminated before Kubernetes was fully-initialized, or for some other reason.<br/>
In this case, open a terminal and validate to ````Local-Deployment/Kubernetes```, then execute the following command:<br/>
`sudo bash -c 'chmod +w kubeFiles && rm -rf kubeFiles; kubeadm reset --force && rm -rf $HOME/.kube/config`<br/>

If there's a problem accessing the Dashboard, it's probably because old-deployment-browser-cookies are used with a new deployment of the Dashboard.<br/>
In that case, delete the "localhost" browser-cookies and restart the script.<br/>

**Note**: Make sure you terminate the popped-up terminal serving kubernetes, before any new deployment!