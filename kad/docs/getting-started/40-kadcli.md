
# kadcli: the KAD CLI

## Server deployment

If you performed the installation from scratch using Kind, as described in a [previous chapter](./10-kind.md), 
the KAD server (`kad-webserver`) is already installed.

For [installation on an existing cluster](./05-installation-existing-cluster.md), you need to activate it. 
To do this, edit the following file:

???+ abstract "cluster/kadtest1/system/_kad-webserver.yaml"

    ``` yaml
    componentReleases:
      - name: kad-webserver
        enabled: true
        component:
          name: kad-webserver
          version: 1.0.0
          parameters:
            ssl: false
            debug: false
            deploymentLocation: clusters/kadtest1/deployments
            replicaCount: 1
        namespace: flux-system
    ```

- If you have changed the cluster name, adjust the `deploymentLocation` parameter.
- If your ingress controller supports 'SSL passthrough' mode, you can set the `ssl` flag to `true`.

This `componentRelease` references a `component` that relies on the context defined in the previous chapter. 
It is, therefore, crucial that the context is configured as previously described.

You can find the definition of this component at the following location:

???- abstract "components/system/kad-webserver.yaml"

    ``` yaml
    components:
    
      - name: kad-webserver
        version: 1.0.0
        source:
          defaultVersion: 0.6.0-snapshot
          allowedVersions:
            - 0.6.0-snapshot
            - 0.6.0
          ociRepository:
            url: oci://quay.io/kubotal/charts/kad-webserver
            interval: 1m
        parameters:
          host: # Allow override of kad.{{ .Context.ingress.hostPostfix }}
          ssl: true
          debug: false
          replicaCount: 2
          deploymentLocation: # TBD for GIT Gateway
        catalogs:
          - system
        parametersSchema:
          document: schema-parameters-kad-webserver-1.0.0
        contextSchema:
          document: schema-context-kad-webserver-1.0.0
        dependsOn:
          - ingress
        values: |
          replicaCount: {{ .Parameters.replicaCount }}
          ingress:
            {{- if .Parameters.host }}
            host: {{ .Parameters.host }}
            {{- else }}
            host: kad.{{ required ".Context.ingress.hostPostfix must be defined if '.Parameters.host' is not" .Context.ingress.hostPostfix }}
            {{- end }}
          webConfig:
            server:
              ssl: {{ .Parameters.ssl }}
              {{- if .Parameters.ssl }}
              certificateIssuer: {{ required ".Context.ingress.clusterIssuer must be defined if '.Parameters.ssl: true'" .Context.ingress.clusterIssuer }}
              {{- end }}
            {{- with .Parameters.deploymentLocation }}
            gitGateway:
              deploymentLocation: {{ . }}
            {{- end }}
          {{- if .Parameters.debug }}
          logger:
            mode: dev
            level: debug
          image:
            pullPolicy: Always
          {{- end }}
    ```

Once these modifications are performed, you can activate the service by renaming the file
`cluster/kadtest1/system/_kad-webserver.yaml` by removing the leading underscore _.

After committing the changes to Git, you should see the corresponding pod appear:

``` bash
$ kubectl get pods -n flux-system
NAME                                       READY   STATUS    RESTARTS      AGE
helm-controller-6f558f6c5d-pk5v9           1/1     Running   4 (24h ago)   10d
kad-controller-5667bc7585-tpk2g            1/1     Running   0             5m50s
kad-webserver-6d8cdc9bb7-m4787             1/1     Running   0             5m45s
kustomize-controller-74fb56995-dq4c8       1/1     Running   4 (24h ago)   10d
notification-controller-5d794dd575-bqm8b   1/1     Running   3 (24h ago)   10d
source-controller-6d597849c8-djq46         1/1     Running   4 (24h ago)   10d
```


## DNS Configuration

Finally, make sure your DNS is configured to resolve the host `kad.ingress.kadtest1.k8s.local` (or your modified version) 
to the ingress entry point.

For Kind clusters, this host must resolve to `localhost`. Refer to the `/etc/hosts` configuration described in the 
[relevant chapter](./10-kind.md/#dns-configuration).

## Client Installation

The `kadcli` client is a simple binary. You only need to download the version matching your KAD installation and
architecture from the following link: https://github.com/kubotal/kad-controller/releases.

> To retrieve version of the KAD server:
    ``` bash
    kubectl get -n flux-system deployment kad-controller -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d ":" -f 2
    ```

Then, rename the file to `kadcli`, make it executable (`chmod +x kadcli`), and add it to your system's PATH.

## Client Usage

This tool is intended for Kubernetes/KAD administrators. It assumes your Kubernetes client configuration is already 
set up and grants full administrative rights.

From this, configuration is automated. When launched, `kadcli` will access the cluster to retrieve the connection URL 
and a security token stored in a kubernetes `secret` (`flux-system:kad-webserver-access`)

`kadcli` organizes its commands into three main group of subcommands:

- `kad`: The primary group, allowing interaction with the KAD object repository.
- `git`: Provides commands to list and modify contents in a specific Git directory.
- `k8s`: Allows viewing certain Kubernetes resources.

It is clear that the last two command groups overlap with kubectl and a Git client. 
They exist only because the underlying REST APIs are designed to be used by a web front end.

An exhaustive list of commands for each group is provided in a dedicated chapter. Below are a few examples:

- Perhaps the most useful: check errors.
    
    ```
    $ kadcli kad check
    No errors!
    ```

    An alternative to searching through `kad-controller` logs.

- Listing all defined components.

    ```
    $ kadcli kad components list
    NAME           VERSION  SPD  PRTC  ERR  FILE                                                                              PATH  TITLE  CATALOGS  RELEASES
    cert-issuers   1.0.0    no   no    no   /work/webserver/primary-sources/flux-system/components/system/cert-issuers.yaml   /
    cert-manager   1.0.0    no   no    no   /work/webserver/primary-sources/flux-system/components/system/cert-manager.yaml   /
    ingress-nginx  1.0.0    no   no    no   /work/webserver/primary-sources/flux-system/components/system/ingress-nginx.yaml  /
    kad-webserver  1.0.0    no   no    no   /work/webserver/primary-sources/flux-system/components/system/kad-webserver.yaml  /            system    kad-webserver
    podinfo        0.1.0    no   no    no   /work/webserver/primary-sources/flux-system/components/apps/podinfo-0.1.0.yaml    /                      podinfo1
    podinfo        0.2.0    no   no    no   /work/webserver/primary-sources/flux-system/components/apps/podinfo-0.2.0.yaml    /                      podinfo2
    podinfo        0.3.0    no   no    no   /work/webserver/primary-sources/flux-system/components/apps/podinfo-0.3.0.yaml    /                      podinfo3
    ```

- Listing all active deployments.

    ```
    $ kadcli kad componentReleases list
    NAME           COMPONENT            NAMESPACE    ENB.  SPD  ERR  PRTC  DEPENDENCIES  FILE                                                                                     PATH  CATALOG
    kad-webserver  kad-webserver:1.0.0  flux-system  YES   no   no   no    _CLUSTER_     /work/webserver/primary-sources/flux-system/clusters/kadtest1/system/kad-webserver.yaml  /     system
    podinfo1       podinfo:0.1.0        podinfo1     YES   no   no   no                  /work/webserver/primary-sources/flux-system/clusters/kadtest1/deployments/podinfo1.yaml  /
    podinfo2       podinfo:0.2.0        podinfo2     YES   no   no   no                  /work/webserver/primary-sources/flux-system/clusters/kadtest1/deployments/podinfo2.yaml  /
    podinfo3       podinfo:0.3.0        podinfo3     YES   no   no   no                  /work/webserver/primary-sources/flux-system/clusters/kadtest1/deployments/podinfo3.yaml  /
    ```

- Inspecting the context.

    ```
    $ kadcli kad context
    _clusterRoles:
      ingress: true
      loadBalancer: true
    ingress:
      className: nginx
      clusterIssuer: cluster-issuer1
      hostPostfix: ingress.kadtest1.k8s.local
    ```

## Curl commands

If you want to access this API directly, for example to build some tools around KAD, you can use the `--curl` option 
on almost all commands the generate the REST API call. 

```
$ kadcli kad components list --curl
curl -H "Authorization: Bearer 247QSAj97rBWd1L1CftfVfCe8doEnqr1" -X GET https://kad.ingress.kadtest2.k8s.local/api/kad/v1/mycluster/components
```

```
$ curl -H "Authorization: Bearer 247QSAj97rBWd1L1CftfVfCe8doEnqr1" -X GET https://kad.ingress.kadtest2.k8s.local/api/kad/v1/mycluster/components
[{"kind":"component","spec":{"name":"ingress-nginx","version":"1.0.0","catalogs":null,"usage":{"text":"","file":"","document":""},"tmpl__":{"Name":"helmRelease","Version":"1.0.0"}...........
```