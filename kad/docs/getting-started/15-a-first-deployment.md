
# A first deployment

> This part is relevant whatever installation type you performed. For this reason, when the cluster name is specified, 
it is set as `kadtestX`, to be replaced by `kadtest1` or `kadtest2`.

## The component object

In KAD, the base deployable unit is called a `component`. A `compoonent` is in fact a wrapper around an Helm Chart.

You will find a first sample of such object in the Git repository:

???+ abstract "components/apps/pod-info-0.1.0.yaml"

    ``` { .yaml } 
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

- A component has a `name` and a `version`attributes. Note that the version of the component is not related to the version of the 
referenced Helm chart.

  - The `source` sub-element references the Helm chart that will be deployed. The version of this chart can be specified 
  during deployment. If not specified, the value of `defaultVersion` will be used.

    The source is of type `helmRepository`. The authors of `podinfo` provide such repository. Depending of the situation, 
    a source can also be a `gitRepository`, or an `OCIRepository`. More on this later in this doc. 

- The `allowCreateNamespace` attribute allows the creation of the namespace specified during deployment, if it does not
already exist.

- The `values` element defines a template that will be rendered to generate the `values.yaml` file used for deploying 
the Helm chart.

    - The templating engine used is the same as Helm's. Therefore, it will not be detailed here.
    - However, the data model is different. It includes, in particular, a root object `.Parameters` that contains values 
      which will be defined during deployment.
    - Although it may look like a `yaml` snippet, it is in fact a string, to allow insertion of template directive.

- The `parameters` attribute allows default values to be set to complement those provided during deployment. 
It can also be used to document all the values to be supplied. (By analogy, this serves the same purpose as the 
`values.yaml` file included in any well-designed Helm chart.)

This description only covers a subset of the possible attributes for a `component`. 
You can find a more comprehensive description in the [Guide](../guide/component.md) section.

## The componentRelease object

A `componentRelease` represents a deployed instance of a `component`.

The presence of such an object triggers the creation of a Kubernetes resource of type `helmRelease`, 
which will be handled by FluxCD to proceed with the deployment of the Helm chart.

Here is a first example of the deployment of a `componentRelease`:


???+ abstract "clusters/kadtestX/deployments/_podinfo1.yaml"

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
            fqdn: podinfo1.ingress.kadtestX.k8s.local # To adjust to your local context
        namespace: podinfo1
    ```

- The `name` of this deployment must be globally unique for a cluster. It will also be used as name for the helmRelease resource.
- Next, there is the reference to the `component` being used, along with its version.

- The `component.config` attribute allows passing information about how the deployment will be performed by FluxCD. 
Here, the namespace is created if it does not already exist.

    > This can be prevented in the `component` definition, by setting `allowCreateNamespace` to false.

- The `component.parameters` attribute will populate the data model used to render the template 
provided by the `values` attribute of the component.

- The `namespace` attribute specify where this component will be deployed.

## Making the Deployment effective

As stated earlier, the presence of a `componentRelease` object triggers its deployment. However, in this case, 
despite having a `componentRelease` named `podinfo1`, there is no corresponding active deployment in the cluster.

The reason lies in a convention followed by KAD: files with names starting with an underscore ('_') are ignored. 
For KAD, the file `.../deployments/_podinfo1.yaml` is nonexistent.

Before proceeding with the deployment, the `parameters.fqdn` attribute must be adjusted to a valid FQDN within your context. 
Additionally, the `parameters.ingressClassName` attribute may need to be updated if you are using an ingress controller 
other than `nginx`.

Once these modifications are complete, rename the file to `.../deployments/podinfo1.yaml` (removing the leading 
underscore) and commit and push these changes to the GitHub repository.

After a short period, the deployment should become effective, as shown below:

``` shell
$ kubectl get pods -n podinfo1
NAME                       READY   STATUS    RESTARTS   AGE
podinfo1-bf57f5955-vfzxb   1/1     Running   0          37s
```

And an ingress be created:

``` shell
$ kubectl get ingress -n podinfo1
NAME       CLASS   HOSTS                                 ADDRESS         PORTS   AGE
podinfo1   nginx   podinfo1.ingress.kadtestX.k8s.local   192.168.56.11   80      50s
```

> If this is not the case, check the logs of the `kad-controller` pod in the `flux-system` namespace. More info on [Debugging](./30-debugging.md)

It is assumed your DNS is configured to resolve this hostname to the ingress controller entrypoint:

- In case of an existing cluster, it is assumed you can configure the DNS. Otherwise, you can use your local `/etc/hosts` file. 
- In case of the Kind cluster, this configuration has been described with the cluster deployment. 

Now, pointing your browser to `http://podinfo1.ingress.kadtestX.k8s.local` should display the `podinfo` page.

If you want to dig more on this, you can have a look of the generated FluxCD object:

``` shell
$ kubectl get helmReleases -n flux-system
NAME             AGE   READY   STATUS
kad-controller   24h   True    Helm upgrade succeeded for release flux-system/kad-controller.v2 with chart kad-controller@0.6.0-snapshot+fa7332def1eb
podinfo1         10h   True    Helm install succeeded for release podinfo1/podinfo1.v1 with chart podinfo@6.7.1
```

A key point of interest is the result of rendering the `values` section of the component. This rendered output becomes part of the `helmRelease`.

``` shell
$ kubectl get helmReleases -n flux-system podinfo1 -o jsonpath={$.spec.values} | yq -P
ingress:
  className: nginx
  enabled: true
  hosts:
    - fqdn: podinfo1.ingress.kadtestX.k8s.local
      paths:
        - path: /
          pathType: ImplementationSpecific
```

> `yq` is a small filter tool to handle json and yaml format 

For the deployment process, KAD also creates a FluxCD `helmRepositories` object. Note the name of this object, as it ensures 
uniqueness when two deployments require the same helmRepository with identical characteristics.

``` shell
$ kubectl get helmRepositories -n flux-system
NAME                                             URL                                      AGE   READY   STATUS
https---stefanprodan-github-io-podinfo-1h-unpr   https://stefanprodan.github.io/podinfo   10h   True    stored artifact: revision 'sha256:60fd41713cc89f0b18abc263e9c7fa9690559de220c49c1fb5b25fc3c5d3f0a6'
```

## Application removal

If the `componentRelease` object is no longer visible to KAD, it will consider that the application should be 
uninstalled and act accordingly.

To make it invisible to KAD, you can:

- Comment out the YAML block
- Delete the file
- Rename the file with a leading _ character

If this behavior is considered risky (for example, if the application contains persistent data), several safeguards 
can be implemented. A [dedicated chapter](./xxxxx.md) is provided to cover this aspect in detail.

> The created namespace is NOT deleted
