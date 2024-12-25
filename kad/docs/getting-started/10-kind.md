# Installation on kind

This section will guide you through creating a Kubernetes cluster on your workstation using Docker and Kind.

Subsequently, FluxCD and KAD will be installed, which will automatically deploy middleware components such as cert-manager and ingress-nginx.

## Prerequisite:

The following components must be installed on your workstation:

- Docker 
- Kubectl
- [Kind](https://kind.sigs.k8s.io/)
- [Flux CLI](https://fluxcd.io/flux/installation/#install-the-flux-cli)

The Docker daemon must be running, and you need to have an active internet connection.

Additionally, the Kind cluster will be configured to use ports 80 and 443, so these ports must be available.

## Configuration

Let’s examine the content of the repository you created in the [initial steps](initial-steps.md):

```
├── README.md
├── clusters
│   ├── kadtest1
│   │   └── .....
│   └── kadtest2
│       ├── deployments
│       │   └── _podinfo1.yaml
│       ├── flux
│       │   └── kad.yaml
│       ├── system
│       │   └── .....
│       └── context.yaml
└── components
    ├── apps
    │   ├── pod-info-0.1.0.yaml
    │   └── .....
    └── system
        └── .....
```

At the root level, you will find two directories:

- `clusters` which will contain a subdirectory for each managed cluster.
- `components` which can be understood as a library of components ready to be installed.

In the `clusters` directory, you will find two subdirectories:

- `kadtest1` which corresponds to the cluster used in the first installation variant.
- `kadtest2` which corresponds to the cluster used in the this section.

The `kadtest2` directory itself contains three subdirectories and a file:

- `deployments`, intended to store the definitions of the deployed applications.
- `system`, containing the middleware deployment, such as cert-manager, ingress, .... 
- `context.yaml`, a file containing all cluster's context information. More on this later.
- `flux` for use by FluxCD. All Kubernetes manifests placed in this directory will be applied by FluxCD during its
  initialization. Here, you will find the deployment manifest for KAD: `kad.yaml`.

File `clusters/kadtest2/flux/kad.yaml`:

``` yaml
--- 
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: kad-controller
  namespace: flux-system
spec:
  .....
  values:
    ....
    config:
      ....
      primarySources:
        - name: flux-system
          namespace: flux-system
          kadFiles:
            - clusters/kadtest2/deployments
            - clusters/kadtest2/system
            - clusters/kadtest2/context.yaml
            - components
      .....
```

The entire content of this manifest will not be detailed here. However, it is important to focus on a specific part:
`spec.values.config.primarySources[0].kadfiles`. This specifies the list of directories (or files) from the repository
root that will be taken into account by KAD.

## Creating the Cluster

Run the following commands to create the cluster.

```
cat >/tmp/kadtest2-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kadtest2
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    protocol: TCP
  - containerPort: 30443
    hostPort: 443
    protocol: TCP
EOF

kind create cluster --config /tmp/kadtest2-config.yaml
```

These commands will create a fully operational cluster with a single node serving as both the control-plane and the worker.

Note the `extraPortMapping` configuration, which will later allow access to the ingress-controller from your workstation once this component is deployed.

The output should look like this:

```
Creating cluster "kadtest2" ...
 ✓ Ensuring node image (kindest/node:v1.31.0) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kadtest2"
You can now use your cluster with:

kubectl cluster-info --context kind-kadtest2

```

Then you can check the new cluster is up and running:

```
$ kubectl get pods -A
NAMESPACE            NAME                                             READY   STATUS    RESTARTS   AGE
kube-system          coredns-6f6b679f8f-hlrms                         0/1     Pending   0          11s
kube-system          coredns-6f6b679f8f-qw824                         0/1     Pending   0          11s
kube-system          etcd-kadtest2-control-plane                      1/1     Running   0          18s
kube-system          kindnet-l6z4t                                    1/1     Running   0          11s
kube-system          kube-apiserver-kadtest2-control-plane            1/1     Running   0          17s
kube-system          kube-controller-manager-kadtest2-control-plane   1/1     Running   0          17s
kube-system          kube-proxy-xmm7d                                 1/1     Running   0          11s
kube-system          kube-scheduler-kadtest2-control-plane            1/1     Running   0          17s
local-path-storage   local-path-provisioner-57c5987fd4-sxsqb          0/1     Pending   0          11s
```

## Creating a Certificate Authority (CA)

Securing HTTP Flux communications requires the use of certificates. In the Kubernetes ecosystem, these certificates 
can be automatically generated using [cert-manager](https://cert-manager.io/).

`cert-manager` requires a Certificate Authority (CA). There are several options for this:

- Use an external CA. This requires additional configuration that is outside the scope of this tutorial.
- Use a CA based on a self-signed certificate. This is the simplest solution but will only be valid for the lifetime of the cluster.
- Create a local CA that will be generated and stored locally, independently of the cluster. 
  This allows you to trust the CA locally on your workstation.

This third option is described here:

> You will need the `openssl` command to create the CA.

In a working directory, save the following script:

???+ abstract "make-ca.sh"

    ``` { .bash .copy } 
    #!/bin/bash
    
    MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # CA name
    CA=ca
    TF=${MYDIR}/kad-ca
    
    SUBJECT="/C=FR/ST=Paris/L=Paris/O=Kubotal/OU=R&D/CN=ca.kad.kubotal.io"
     
    if [ -f "${TF}/${CA}.crt" ]
    then
        echo "---------- CA already existing"
        exit 1
    fi
    
    mkdir -p ${TF}
    
    cat << EOF > ${TF}/req.cnf
    [ req ]
    #default_bits		= 2048
    #default_md		= sha256
    #default_keyfile 	= privkey.pem
    distinguished_name	= req_distinguished_name
    attributes		= req_attributes
    
    [ req_distinguished_name ]
    
    [ req_attributes ]
    challengePassword		= A challenge password
    challengePassword_min		= 4
    challengePassword_max		= 20
    
    [ v3_ca ]
    basicConstraints = critical,CA:TRUE
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer:always
    
    EOF
        
    echo "---------- Create CA Root Key"
    openssl genrsa -out ${TF}/${CA}.key 4096 2>/dev/null
    
    echo "---------- Create and self sign the Root Certificate"
    openssl req -x509 -new -nodes -key ${TF}/${CA}.key -sha256 -days 3650 -out ${TF}/${CA}.crt -extensions v3_ca -config ${TF}/req.cnf -subj ${SUBJECT}
    
    #echo "---------- Convert to PEM"
    #openssl x509 -in ${TF}/${CA}.crt -out ${TF}/${CA}.pem -outform PEM
    
    echo "---------- have a look on CA:"
    openssl x509 -in ${TF}/${CA}.crt -text -noout | head -n 450
    ```

You can modify the SUBJECT variable to replace with your own attributes.

Running this script will generate the `ca.crt` and `ca.key` files, which constitute your new CA. 

Store these files in a secure location, as the private key must remain confidential.

Now save and run the following script:

???+ abstract "issuer-secrets.sh"

    ``` { .bash .copy } 
    #!/bin/bash
    
    MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # CA name
    CA=ca
    TF=${MYDIR}/kad-ca
    
    kubectl create namespace cert-manager
    kubectl create -n cert-manager secret generic cluster-issuer-kad --from-file=tls.crt=${TF}/ca.crt --from-file=tls.key=${TF}/ca.key
    kubectl create -n cert-manager secret generic cluster-issuer-kad-ca --from-file=tls.crt=${TF}/ca.crt
    ```

It will store the CA in two secrets that will be accessed by cert-manager.


## Bootstrap

The bootstrap process will modify the content of the repository. Therefore, you need to provide it with a GitHub token
that has the appropriate permissions. (You can find more detailed information on this aspect in the [FluxCD documentation](https://fluxcd.io/flux/installation/bootstrap/github/#github-pat).)

```
export GITHUB_TOKEN=<Your GitHub token>
```

Then you can proceed withe the bootstrap.

If the repository is in your personal GitHub account:

``` shell
flux bootstrap github \
--owner=<GitHub user> \
--repository=<Repository name> \
--branch=main \
--interval 15s \
--read-write-key \
--personnal \
--path=clusters/kadtest2/flux
```

Or if the repository is in an organization account:

``` shell
flux bootstrap github \
--owner=<GitHub organization> \
--repository=<Repository name> \
--branch=main \
--interval 15s \
--read-write-key \
--path=clusters/kadtest2/flux
```

> Adjust the path to match the cluster name if you have changed it.

The output should look like this:

```
► connecting to github.com
► cloning branch "main" from Git repository "https://github.com/kubotal/kad-infra-doc.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed component manifests to "main" ("8202c5eb6873710d725f52dfdacb0cfd3afdf787")
► pushing component manifests to "https://github.com/kubotal/kad-infra-doc.git"
► installing components in "flux-system" namespace
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBM7kQ/I7JP79UOhXZDY4IogerKItupdzjCJl0mGCZU6OmkvZIObnlZwG+8EmNxScdXrMNYRRUIE8Bkr4Q5WGfl1itS/ziD73gTFwOWKxHYCsbb6WisqbQ6Ht5zRsa8twsA==
.......
✔ source-controller: deployment ready
✔ all components are healthy

```

The bootstrap command above does the following:

- Adds Flux component manifests to the repository (In the `clusters/kadtest2/flux/flux-system` location)
- Deploys Flux Components to your Kubernetes Cluster.
- Create an SSH deploy key to be used by FluxCD controller to access the Git repository
- Configures Flux components to track the path `clusters/kadtest2/flux` in the repository.
- As there is a manifest `kad.yaml` in this folder, deploy the `kad-controller`
- This `kad-controller` now track all files/folders defined in its `kadFiles` configuration. 
  This triggers the creation of several `helmReleases`.
- Flux CD handles the deployment of these `HelmReleases`, taking their interdependencies into account. 


If installation is successful, several new pods should be up and running:

``` shell
$ kubectl get -A pods
NAMESPACE            NAME                                             READY   STATUS    RESTARTS         AGE
cert-manager         cert-manager-74c755695c-4qqrr                    1/1     Running   3 (3m19s ago)    2d15h
cert-manager         cert-manager-cainjector-dcc5966bc-d6t9h          1/1     Running   10 (2m26s ago)   2d15h
cert-manager         cert-manager-webhook-dfb76c7bd-9k8r7             1/1     Running   1 (3m19s ago)    2d15h
flux-system          helm-controller-7f788c795c-qj5rg                 1/1     Running   12 (2m32s ago)   2d15h
flux-system          kad-controller-76b5765554-mdh9c                  1/1     Running   6 (3m19s ago)    44h
flux-system          kad-webserver-bb74469f4-f9l7n                    1/1     Running   6 (2m54s ago)    44h
flux-system          kustomize-controller-b4f45fff6-8gvcw             1/1     Running   19 (2m27s ago)   2d15h
flux-system          notification-controller-556b8867f8-fsnqr         1/1     Running   15 (2m31s ago)   2d15h
flux-system          source-controller-77d6cd56c9-682nx               1/1     Running   31 (2m31s ago)   2d15h
ingress-nginx        ingress-nginx-controller-684d6d7756-9nrnx        1/1     Running   1 (3m19s ago)    47h
kube-system          coredns-6f6b679f8f-n6mrf                         1/1     Running   1 (3m19s ago)    2d15h
kube-system          coredns-6f6b679f8f-pnms7                         1/1     Running   1 (3m19s ago)    2d15h
kube-system          etcd-kadtest2-control-plane                      1/1     Running   0                3m2s
kube-system          kindnet-822lz                                    1/1     Running   1 (3m19s ago)    2d15h
kube-system          kube-apiserver-kadtest2-control-plane            1/1     Running   0                3m2s
kube-system          kube-controller-manager-kadtest2-control-plane   1/1     Running   7 (3m19s ago)    2d15h
kube-system          kube-proxy-br722                                 1/1     Running   1 (3m19s ago)    2d15h
kube-system          kube-scheduler-kadtest2-control-plane            1/1     Running   5 (3m19s ago)    2d15h
local-path-storage   local-path-provisioner-57c5987fd4-l49wk          1/1     Running   2 (2m29s ago)    2d15h
```

Note the new pods compared to the initial state:

- The ones in `flux-system` namespace, from FluxCD and KAD
- The ones in `cert-manager` namespace
- The one in `ingress-nginx` namespace

> If you have cloned locally the repository, perform a `git pull` to update your local workspace with the modifications
  performed by this process

## DNS Configuration

The installation process will attach an ingress controller to ports 80 and 443 of your workstation.

To access the URLs you will deploy later, these URLs must resolve to `localhost`. The simplest solution is to modify the 
local `/etc/hosts` file as the following:

```
127.0.0.1	localhost podinfo1.ingress.kadtest2.k8s.local podinfo2.ingress.kadtest2.k8s.local kad.ingress.kadtest2.k8s.local
```

These values anticipate what will be deployed later in these tutorials.

> Unfortunately, this method does not allow defining wildcard DNS entries (e.g., `*.ingress.kadtest2.k8s.local`). Installing alternatives that provide this functionality (such as dnsmasq) is outside the scope of this documentation.

You can now follow up with the [first deployment](./15-a-first-deployment.md) part

