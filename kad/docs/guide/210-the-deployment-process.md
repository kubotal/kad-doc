# The deployment process

This chapter describe how the KAD files are loaded and activated

The starting point is the `kad.yaml` file mentioned in the installation section.

``` yaml
---
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
            - clusters/kadtest1/context.yaml
            - components
        - location: /kad-controller
          kadFiles:
            - tmpl            
      .....
```

The first `primarySource`, named `flux-system` in the `flux-system` namespace, references our Git repository.

The second `primarySource` corresponds to a local directory within the container. It contains the base templates used to
generate FluxCD resources.

The `kadfiles` entries are lists of files or directories that will be recursively explored. KAD will process all files that:

- Have a `.yaml` extension (and not `.yml`)
- Do not have base names starting or ending with the character _.
- Similarly, directories with names starting or ending with _ will not be explored.

These YAML files must be dictionaries of KAD object types, with each type containing a list of objects.

For example, a valid file might look like this:

???+ abstract "podinfo12.yaml"

    ``` { .yaml }
    componentReleases:
      - name: podinfo1
        component:
          name: podinfo
          version: 0.1.0
          config:
            install:
              createNamespace: true
          parameters:
            # ingressClassName: # To be set if != nginx
            url: podinfo1.ingress.kadtest1.k8s.local # To adjust to your local context
        namespace: podinfo1
    
      - name: podinfo2
        component:
          name: podinfo
          version: 0.1.0
          config:
            install:
              createNamespace: true
          parameters:
            # ingressClassName: # To be set if != nginx
            url: podinfo2.ingress.kadtest1.k8s.local # To adjust to your local context
        namespace: podinfo2
    
    components:
      - name: podinfo
        version: 0.1.0
        source:
          defaultVersion: 6.7.1
          helmRepository:
            url: https://stefanprodan.github.io/podinfo
            chart: podinfo
        allowCreateNamespace: true
        parameters:
          ingressClassName: nginx
          fqdn: # TBD
        values: |
          ingress:
            enabled: true
            className: {{ .Parameters.ingressClassName }}
            hosts:
              - host: {{ .Parameters.fqdn }}
                paths:
                  - path: /
                    pathType: ImplementationSpecific
    ```

This file includes two `componentRelease` objects and the associated `component`.

Except for the second `componentRelease` `'podinfo'`, it is equivalent to what was previously deployed.

KAD does not impose any restrictions on how you organize your files. Similarly, the directory structure is entirely
irrelevant to KAD. You can define all your objects in a single file or create one file per object. The result will be exactly the same.

All objects collected by KAD are consolidated into a single internal repository (or referential), independent of their location in the file tree.

One consequence of this is that, for a given object type, the name must be globally unique (or the name/version pair if
the object is of a versioned type).

Now, here is the detailed process triggered in previous example of deployment:

- The file `.../deployments/_podinfo1.yaml` was renamed to `.../deployments/podinfo1.yaml`.
- This modification was committed and pushed to the GitHub repository.
- The `kad-controller` includes a watcher on this repository, which notifies it of any changes.
- The controller performs a Git clone of the repository and rebuilds its internal referential.
- From this internal referential, it recreates all the `helmRelease` objects and applies them to Kubernetes.
- FluxCD then installs or upgrades the corresponding Helm deployments for only the `helmReleases` objects that were
  effectively created or modified.



