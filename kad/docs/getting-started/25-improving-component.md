# Improving our component

This chapter describes an evolution of our `podinfo` component, adding support for secure connections using the 
TLS protocol.

It assumes that the cluster includes a certificate generation tool: [cert-manager](https://cert-manager.io/), providing an issuer of type `ClusterIssuer`.

If this is not the case, we still recommend reading this chapter as it contains general information.

If you are using the Kind cluster as described earlier, these prerequisites are, of course, satisfied.

## The new component object

This new version of the component is already defined in the GIT repository, at the following location:

File: `components/apps/pod-info-0.2.0.yaml`

```
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
      url: # TBD
      tls: false
      certificateIssuer: # TBD if tls == true
    values: |
      ingress:
        enabled: true
        className: nginx
        {{- if .Parameters.tls }}
        annotations:
          cert-manager.io/cluster-issuer: {{ required "`.Parameters.certificateIssuer` must be defined if tls: true" .Parameters.certificateIssuer}}
        {{- end }}
        hosts:
          - host: {{ .Parameters.url }}
            paths:
              - path: /
                pathType: ImplementationSpecific
        {{- if .Parameters.tls }}
        tls:
          - secretName: {{ .Meta.componentRelease.name }}-tls
            hosts:
              - {{ .Parameters.url }}
        {{- end }}
```

The first difference is that the version number has been incremented.

Two additional `parameters` have been added:

- `tls`: A boolean to enable or disable the secure protocol.
- `certificateIssuer`: The `ClusterIssuer` that will be used to generate the certificate used by the ingress controller.

The template defined by the `values` attribute has also been updated to account for the optional TLS configuration, 
adapting it to the format required by the Helm Chart of `podinfo`.

We can also notice the appearance of a new root object: `.Meta`, which allows retrieving the deployment name.

The goal here is to name the secret that stores the certificate. Therefore, we need a name that ensures its uniqueness.

## The new componentRelease

To deploy a component with this version, you may create a new file in Git in the deployment folder:

File: `cluster/kadtest1/deployments/podinfo2.yaml`
```
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
        url: podinfo2.ingress.kadtest1.k8s.local # To adjust to your local context
        tls: true
        certificateIssuer: cluster-issuer1 # To adjust to your local context
    namespace: podinfo2
```

After committing and pushing this addition, you should have a new pod `podinfo2` and a new ingress.

You should be able to point your browser to `https://podinfo2.ingress.kadtest1.k8s.local` (Note the `https`).

Note than the initial deployment (`podinfo1`) is retained with its original characteristics (plain text connection). 
Component versioning allows multiple versions to coexist.

Keep in mind that the Git repository should, in principle, always reflect the current state of your cluster(s). 
This state is often heterogeneous in terms of component versions.

The principle is therefore not to modify a component that has been deployed but to create a new version in case of evolution.

Once all associated deployments have been migrated to the new version, the initial component can be safely removed.

As a matter of exercise, you may update the `podinfo1` `componentRelease` to change the component version number. 
You will also need to set `tls: true` and the `certificateIssuer` value.




