# The context

## Introduction

When examining the initial deployments, we can identify configuration parameters or parameter elements that are repeated. 
In fact, these values are not tied to a specific deployment but are global for a given cluster.

KAD provides a mechanism to handle this kind of global variables: the `context`.

The `context` is a variable container. It is unique to a KAD repository, and therefore to a cluster.

It is defined in one or more `kadFile`, as shown in the example below.

``` yaml
context:

  ingress:
    className: nginx
    clusterIssuer: cluster-issuer1
    hostPostfix: ingress.kadtest1.k8s.local
```

> The `context:` entry introduces a map (or dictionary), unlike other types, which are lists.

In this example, we find variables that are global to the cluster and common to all deployments:

- The ingress controller class (here, nginx).
- The issuer used for all ingresses.
- The common and final part of the FQDN associated with the different ingresses.

This context will then be accessible in the data model used during the rendering of values at deployment time.

For example, here is a new version of the `podinfo` component that will make use of it:

File: `components/apps/podinfo-0.3.0.yaml`

``` yaml
components:
  - name: podinfo
    version: 0.3.0
    source:
      defaultVersion: 6.7.1
      helmRepository:
        url: https://stefanprodan.github.io/podinfo
        chart: podinfo
    allowCreateNamespace: true
    parameters:
      hostname: # TBD
      tls: false
    values: |
      ingress:
        enabled: true
        className: {{ .Context.ingress.className }}
        {{- if .Parameters.tls }}
        annotations:
          cert-manager.io/cluster-issuer: {{ required "`.Context.ingress.clusterIssuer` must be defined if tls: true" .Context.ingress.clusterIssuer}}
        {{- end }}
        hosts:
          - host: {{ .Parameters.hostname }}.{{ .Context.ingress.hostPostfix }}
            paths:
              - path: /
                pathType: ImplementationSpecific
        {{- if .Parameters.tls }}
        tls:
          - secretName: {{ .Meta.componentRelease.name }}-tls
            hosts:
              - {{ .Parameters.hostname }}.{{ .Context.ingress.hostPostfix }}
        {{- end }}
```


The structure of the context is flexible. However, it must be consistent with the various components that will use it.

## Deployment

For deployment [on an existing cluster](./05-installation-existing-cluster.md), the context is defined in the file:

file: `clusters/kadtest1/context.yaml`

``` yaml
context:

  ingress:
    className: nginx
    clusterIssuer: cluster-issuer1
    hostPostfix: ingress.kadtest1.k8s.local

  _clusterRoles:
    loadBalancer: true
    ingress: true
```


And for the [kind cluster](./10-kind.md):


file: `clusters/kadtest2/context.yaml`

``` yaml
context:

  ingress:
    className: nginx
    clusterIssuer: kad
    hostPostfix: ingress.kadtest2.k8s.local

  _clusterRoles:
    loadBalancer: true
```

Variables starting with the character '_' are reserved by KAD.

In this example, the `_clusterRoles` block pertains to dependency management, a topic that will be addressed later.

It may therefore be necessary to adjust the values (especially in the case of an existing cluster). 
Then, deployment can proceed by creating a new componentRelease.

``` yaml
componentReleases:
  - name: podinfo3
    component:
      name: podinfo
      version: 0.3.0
      config:
        install:
          createNamespace: true
      parameters:
        hostname: podinfo3
        tls: true
    namespace: podinfo3
```

Using `context` simplifies the parameters to be provided, now reflecting only deployment-related choices rather than infrastructure constraints.

# Context Construction

When multiple kadFiles contain a `context:` entry, the values are aggregated, following the same logic as `values.yaml`
files in Helm charts.

The order in which the files are declared is therefore important.

As an example, we can redefine our contexts as follows:

- A file containing what is common to all clusters.

    file: `clusters/context.yaml`
    
    ``` yaml
    context:
    
      ingress:
        className: nginx
        clusterIssuer: kad
        hostPostfix: ingress.kadtest1.k8s.local
    ```

- A file for the first cluster:

    file: `clusters/kadtest1/context.yaml`
    
    ``` yaml
    context:
    
      ingress:
        clusterIssuer: cluster-issuer1
        hostPostfix: ingress.kadtest1.k8s.local
    ```

- And another for the second one:

    file: `clusters/kadtest2/context.yaml` 
    
    ``` yaml
    context:
    
      ingress:
        hostPostfix: ingress.kadtest2.k8s.local
    ```

The `clusterIssuer` of the first cluster overrides the general value.

> We removed the `_clusterRoles` block for clarity

The configuration of the `kad-controller` will therefore integrate both the common file and the cluster specific one, 
ordered from the most general to the most specific.

``` yaml
--- 
kind: HelmRelease
....
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
            - components
            - clusters/context.yaml
            - clusters/kadtestX/context.yaml
      .....
```
