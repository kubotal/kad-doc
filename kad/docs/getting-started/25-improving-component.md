# Improving our component

This chapter describes an evolution of our `podinfo` component, adding support for secure connections using the 
TLS protocol.

It assumes that the cluster includes a certificate generation tool: [cert-manager](https://cert-manager.io/), providing an issuer of type `ClusterIssuer`.

If this is not the case, we still recommend reading this chapter as it contains general information.

If you are using the Kind cluster as described earlier, these prerequisites are already satisfied.

## The new component object

This new version of the component is already defined in the GIT repository, at the following location:

???+ abstract "components/apps/pod-info-0.2.0.yaml"

    ``` { .yaml }
    components:
      - name: podinfo
        version: 0.2.0
        source:
          defaultVersion: 6.7.1
          helmRepository:
            url: https://stefanprodan.github.io/podinfo
            chart: podinfo
        allowCreateNamespace: true
        parameters:
          ingressClassName: nginx
          fqdn: # TBD
          tls: false
          clusterIssuer: # TBD if tls == true
        values: |
          ingress:
            enabled: true
            className: nginx
            {{- if .Parameters.tls }}
            annotations:
              cert-manager.io/cluster-issuer: {{ required "`.Parameters.clusterIssuer` must be defined if tls: true" .Parameters.clusterIssuer}}
            {{- end }}
            hosts:
              - host: {{ .Parameters.fqdn }}
                paths:
                  - path: /
                    pathType: ImplementationSpecific
            {{- if .Parameters.tls }}
            tls:
              - secretName: {{ .Meta.componentRelease.name }}-tls
                hosts:
                  - {{ .Parameters.fqdn }}
            {{- end }}
    ```

The first difference is that the version number has been incremented.

Two additional `parameters` have been added:

- `tls`: A boolean to enable or disable the secure protocol.
- `clusterIssuer`: The `ClusterIssuer` that will be used to generate the certificate used by the ingress controller.

The template defined by the `values` attribute has also been updated to account for the optional TLS configuration, 
adapting it to the format required by the Helm Chart of `podinfo`.

We can also notice the appearance of a new root object: `.Meta`, which allows retrieving the deployment name.

The goal here is to name the secret that stores the certificate. Therefore, we need a name that ensures its uniqueness.

## The new componentRelease

To deploy a component with this version, you may create a new file in Git in the deployment folder:

???+ abstract "cluster/kadtestX/deployments/podinfo2.yaml"

    ``` { .yaml .copy }
    componentReleases:
      - name: podinfo2
        component:
          name: podinfo
          version: 0.2.0
          config:
            install:
              createNamespace: true
          parameters:
            ingressClassName: # To be set if != nginx
            fqdn: podinfo2.ingress.kadtestX.k8s.local # To adjust to your local context
            tls: true
            clusterIssuer: kad # To adjust to your local context
        namespace: podinfo2
    ```

As usual, some parameters may need adjustment:

- `fqdn`, at least to replace kadtestX
- `clusterIssuer`: If you performed the deployment on kind, as stated in previous chapters, `kad` is the appropriate 
value. Otherwise, the value depends of your cluster configuration.  

After committing and pushing this addition, you should have a new pod `podinfo2` and a new `ingress` kubernetes object.

You should be able to point your browser to `https://podinfo2.ingress.kadtestX.k8s.local` (Note the `https`).

> Of course, your DNS system must resolve `podinfo2.ingress.kadtestX.k8s.local` to your ingress-controller endpoint.

Note than the initial deployment (`podinfo1`) is retained with its original characteristics (plain text connection). 
Component versioning allows multiple versions to coexist.

Keep in mind that the Git repository should, in principle, always reflect the current state of your cluster(s). 
This state is often heterogeneous in terms of component versions.

The principle is therefore not to modify a component that has been deployed but to create a new version in case of evolution.

Once all associated deployments have been migrated to the new version, the initial component can be safely removed.

As a matter of exercise, you may update the `podinfo1` `componentRelease` to change the component version number. 
You will also need to set `tls: true` and the `clusterIssuer` value.




