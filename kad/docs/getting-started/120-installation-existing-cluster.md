# Installation on an existing cluster

## Prerequisites

It's assumed that you have the `kubectl` installed and that your Kubernetes client configuration (in `~/.kube/config`) 
is correctly pointed at your target cluster and that you have **full cluster admin rights**

Your target cluster must:

- match [the FluxCD prerequisites](https://fluxcd.io/flux/installation/#prerequisites).
- Have access to Internet
- Have an ingress controller. This tutorial has been tested with `NGINX ingress controller`, but should be 
easily adapted for another one.

You must also install the [FluxCD CLI client](https://fluxcd.io/flux/installation/#install-the-flux-cli) on your workstation.

> If you do not have access to an appropriate cluster, you can perform a local deployment on your workstation, as described in the [following chapter](./130-kind.md).

## Configuration 

Let’s examine the content of the repository you created in the [initial steps](./110-preparation.md):

```
├── README.md
├── clusters
│   ├── kadtest1
│   │   ├── deployments
│   │   │   └── _podinfo1.yaml
│   │   ├── flux
│   │   │   └── kad.yaml
│   │   ├── system
│   │   │   └── .....
│   │   └── context.yaml
│   └── kadtest2
│       └── .....
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

- `kadtest1` which corresponds to the cluster used in this section.
- `kadtest2` which corresponds to the cluster used in the second installation variant.

The `kadtest1` directory itself contains two subdirectories and a file:

- `deployments`, intended to store the definitions of the deployed applications.
- `context.yaml`, a file containing all cluster's context information. More on this later.
- `flux` for use by FluxCD. All Kubernetes manifests placed in this directory will be applied by FluxCD during its 
  initialization. Here, you will find the deployment manifest for KAD: `kad.yaml`.
- `system`, for usage of future middleware deployments.

Let's take a closer look at the configuration of KAD:

File `clusters/kadtest1/flux/kad.yaml`:

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
            - clusters/kadtest1/deployments
            - clusters/kadtest1/context.yaml
            - components
      .....
```

The entire content of this manifest will not be detailed here. However, it is important to focus on a specific part: 
`spec.values.config.primarySources[0].kadfiles`. This specifies the list of directories (or files) from the repository 
root that will be taken into account by KAD. More on that later.

If you logically wish to replace the name `kadtest1` with the actual name of your cluster, you can rename the 
subdirectory under `clusters`. You must also update this name in the `spec.values.config.primarySources[0].kadfiles` list.

> Note: Don’t forget to commit and push your changes if you modify the repository locally.

## Bootstrap

The bootstrap process will modify the content of the repository. Therefore, you need to provide it with a GitHub token (`PAT` for Personal Access Token)
that has the appropriate permissions. (You can find more detailed information on this aspect in the [FluxCD documentation](https://fluxcd.io/flux/installation/bootstrap/github/#github-pat).)

``` bash
export GITHUB_TOKEN=<Your GitHub token>
```

Then you can proceed withe the bootstrap.

If the repository is in your personal GitHub account:

``` { .bash .copy }
flux bootstrap github \
--owner=<GitHub user> \
--repository=<Repository name> \
--branch=main \
--interval 15s \
--read-write-key \
--personnal \
--path=clusters/kadtest1/flux
```

Or if the repository is in an organization account:

``` { .bash .copy }
flux bootstrap github \
--owner=<GitHub organization> \
--repository=<Repository name> \
--branch=main \
--interval 15s \
--read-write-key \
--path=clusters/kadtest1/flux
```

> Adjust the path to match the cluster name if you have changed it.

The output should look like this:

``` bash
► connecting to github.com
► cloning branch "main" from Git repository "https://github.com/myorga/kad-infra1.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed component manifests to "main" ("d621dc6ab44f52663e1d3393df18ae14192b1888")
► pushing component manifests to "https://github.com/myorga/kad-infra1.git"
► installing components in "flux-system" namespace
......
✔ public key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBHfD5hEc7Ciyth7ZB7t66dukywWFff8hakJki/C5Kf8wOOqKrO9WsOQGblRNXGmfBEtgkOrFmchIeYRLYY4CK8VjOH5rJLZK7/TziP9xM3ljUCByzgd/x28o9598Tku7gg==
✔ configured deploy key "flux-system-main-flux-system-./clusters/kadtest1/flux" for "https://github.com/kubotal/kad-infra-doc"
► applying source secret "flux-system/flux-system"
....
✔ all components are healthy

```

The bootstrap command above does the following:

- Adds Flux component manifests to the repository (In the `clusters/kadtest1/flux/flux-system` location)
- Deploys Flux components to your Kubernetes Cluster.
- Create an SSH deploy key to be used by FluxCD controller to access the Git repository 
- Configures Flux components to track the path `clusters/kadtest1/flux` in the repository.
- As there is a manifest `kad.yaml` in this folder, apply it. This will create the `kad-controller` deployment.


> If you have cloned locally the repository, perform a git pull to update your local workspace with the modifications
  performed by this process


If installation is successful, several pods should be up and running in the `flux-system` namespace.

``` shell
$ kubectl get pods -n flux-system
NAME                                       READY   STATUS    RESTARTS   AGE
helm-controller-6f558f6c5d-pk5v9           1/1     Running   0          38m
kad-controller-7c7748d5c9-spzn2            1/1     Running   0          118s
kustomize-controller-74fb56995-dq4c8       1/1     Running   0          38m
notification-controller-5d794dd575-bqm8b   1/1     Running   0          38m
source-controller-6d597849c8-djq46         1/1     Running   0          38m

```

You can now follow up with the [first deployment](./140-a-first-deployment.md) part

