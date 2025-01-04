
# Dependencies

If we examine how the three components from the previous chapter are deployed, we observe that they are deployed independently at two levels:

- KAD generates the three Helm releases in an undetermined order.
- FluxCD performs the corresponding deployments in parallel, with no concept of order or dependency.

If the system works, it is because the applications are well-designed and operate with a retry logic until they function correctly.

However, this approach can have its limitations. This is why KAD introduces a dependency system between deployments. 

FluxCD allows the definition of dependencies between `helmReleases`. 
KAD leverages this feature internally but adds an abstraction: the concept of `role`.

A deployment can fulfill one (or multiple) roles. Similarly, it can depend on one or more roles.

This abstraction provides much greater flexibility. For example, an application that exposes a web service outside
the cluster depends on the presence of an ingress controller. It will therefore depend on a role named `ingress`, 
regardless of whether this is provided by `nginx`, `Traefik`, `Kong`, or another solution.

The provided role can be defined at the level of a `componentRelease` but also at the `component` level. 
In the latter case, it applies to all `componentReleases` using that component.

Similarly, dependencies can be defined at the `componentRelease` level or at the `component` level.

Here is an updated version of our Redis stack, implementing this new functionality:


???+ abstract "storehouse/redis-stack-3.yaml"

    ``` { .yaml }
    componentReleases:
      - name: redis3-namespace
        component:
          name: namespace
          version: 0.1.0
          parameters:
            name: redis3
            labels:
              my.company.com/project-name: redis
              my.company.com/project-id: redis3
        namespace: default
        roles:
          - redis3-namespace
    
      - name: redis3-redis
        component:
          name: redis
          version: 0.1.0
          parameters:
            password: admin123
            replicaCount: 1
        namespace: redis3
        roles:
          - redis3-redis
        dependsOn:
          - redis3-namespace
    
      - name: redis3-commander
        component:
          name: redis-commander
          version: 0.2.0
          parameters:
            redis:
              host: redis3-redis-master
              password: admin123
            hostname: redis3
            tls: true
        namespace: redis3
        dependsOn:
          - redis3-redis
          - redis3-namespace
    ```

- The `redis3-namespace` component provides the `redis3-namespace` role.
- The `redis3-redis` component depends on the `redis3-namespace` role and provides the `redis3-redis` role.
- The `redis3-commander` component depends on the `redis3-redis` and `redis3-namespace` roles (the latter is redundant, 
  as `redis3-redis` already depends on namespace).

> Since the role naming space is global, it is necessary to prefix all role names with an instance identifier (e.g., `redis3-`).

As before, you need to copy this file into your cluster's deployment directory for it to be processed by KAD.

If you quickly inspect the evolution of the HelmReleases:

``` shell
$ kubectl -n flux-system get helmReleases
NAME               AGE    READY   STATUS
kad-controller     16d    True    Helm upgrade succeeded for release flux-system/kad-controller.v7 with chart kad-controller@0.6.0-snapshot+62ee4747066a
kad-webserver      6d4h   True    Helm install succeeded for release flux-system/kad-webserver.v1 with chart kad-webserver@0.6.0-snapshot+9833fad83b67
redis3-commander   2s     False   dependency 'flux-system/redis3-redis' is not ready
redis3-namespace   2s     True    Helm install succeeded for release default/redis3-namespace.v1 with chart namespace@1.0.0+e8788571eb8c
redis3-redis       2s     False   dependency 'flux-system/redis3-namespace' is not ready
```

You will observe that KAD creates all the HelmReleases immediately. However, some are marked as waiting for a dependency.

> Note that there may be a delay between the completion of one deployment and the initiation of the next. This delay
can last up to 30 seconds. At the end of this chapter, instructions are provided on how to reduce this delay.

The deployment of the Redis cluster is also a process that is not immediate.

``` shell
$ kubectl -n flux-system get helmReleases
NAME               AGE    READY     STATUS
kad-controller     16d    True      Helm upgrade succeeded for release flux-system/kad-controller.v7 with chart kad-controller@0.6.0-snapshot+62ee4747066a
kad-webserver      6d4h   True      Helm install succeeded for release flux-system/kad-webserver.v1 with chart kad-webserver@0.6.0-snapshot+9833fad83b67
redis3-commander   6s     False     dependency 'flux-system/redis3-redis' is not ready
redis3-namespace   6s     True      Helm install succeeded for release default/redis3-namespace.v1 with chart namespace@1.0.0+e8788571eb8c
redis3-redis       6s     Unknown   Running 'install' action with timeout of 3m0s
```

Once it is complete, the deployment of redis-commander can proceed. And, finally, the full stack is deployed


``` shell
$ kubectl -n flux-system get helmReleases
NAME               AGE    READY   STATUS
kad-controller     16d    True    Helm upgrade succeeded for release flux-system/kad-controller.v7 with chart kad-controller@0.6.0-snapshot+62ee4747066a
kad-webserver      6d4h   True    Helm install succeeded for release flux-system/kad-webserver.v1 with chart kad-webserver@0.6.0-snapshot+9833fad83b67
redis3-commander   64s    True    Helm install succeeded for release redis3/redis3-commander.v1 with chart redis-commander@0.6.0+a92d4d2424e5
redis3-namespace   64s    True    Helm install succeeded for release default/redis3-namespace.v1 with chart namespace@1.0.0+e8788571eb8c
redis3-redis       64s    True    Helm install succeeded for release redis3/redis3-redis.v1 with chart redis@20.6.1+55659cf4e324
```

You can verify the successful deployment of the resources:


``` shell
$ kubectl -n redis3 get pods
NAME                                                READY   STATUS    RESTARTS   AGE
redis3-commander-redis-commander-6c657668d7-8f6xf   1/1     Running   0          3m21s
redis3-redis-master-0                               1/1     Running   0          4m19s
redis3-redis-replicas-0                             1/1     Running   0          4m19s
```

``` shell
$ kubectl -n redis3 get ingress
NAME                               CLASS   HOSTS                               ADDRESS         PORTS     AGE
redis3-commander-redis-commander   nginx   redis3.ingress.kadtest1.k8s.local   192.168.56.11   80, 443   4m13s
```

You can also verify how the dependencies are reflected at the HelmReleases level:

???+ abstract "kubectl -n flux-system get helmReleases redis3-commander -o yaml"

    ``` { .yaml }
    apiVersion: helm.toolkit.fluxcd.io/v2
    kind: HelmRelease
    metadata:
      annotations:
        kad.kubotal.io/component-name: redis-commander
        kad.kubotal.io/component-version: 0.2.0
        kad.kubotal.io/file: /Users/sa/dev/d3/git/kad-infra-doc/clusters/kadtest1/deployments/redis-stack-3.yaml
        kad.kubotal.io/path: /
      ......
      name: redis3-commander
      namespace: flux-system
      ......
    spec:
      chart:
        spec:
          chart: k8s/helm-chart/redis-commander
          interval: 1m
          reconcileStrategy: Revision
          sourceRef:
            kind: GitRepository
            name: redis-commander
            namespace: flux-system
          version: '*'
      dependsOn:
      - name: redis3-redis
        namespace: flux-system
      - name: redis3-namespace
        namespace: flux-system
      interval: 1m
      persistentClient: true
      releaseName: redis3-commander
      ....
    ```

Note the `dependsOn` attribute

## kadcli


If you have deployed the kadcli client, you can access a summary of these dependencies:

For the installation on an existing cluster:

``` shell
$ kadcli kad roles list
NAME              PROVIDER(S)       VALID  DEPENDENT(S)
ingress           _CLUSTER_         YES    kad-webserver,redis3-commander
redis3-namespace  redis3-namespace  YES    redis3-commander,redis3-redis
redis3-redis      redis3-redis      YES    redis3-commander
```

For the installation from scratch, with `kind`:


``` shell
$ kadcli kad role list
NAME              PROVIDER(S)       VALID  DEPENDENT(S)
certManager       cert-issuers      YES    ingress-nginx
certManagerBase   cert-manager      YES    cert-issuers
ingress           ingress-nginx     YES    kad-webserver,redis3-commander
loadBalancer      _CLUSTER_         YES    ingress-nginx
redis3-namespace  redis3-namespace  YES    redis3-commander,redis3-redis
redis3-redis      redis3-redis      YES    redis3-commander
```

This list provides for each role:

- Its NAME
- Its PROVIDER, the `componentRelease` that fulfills this role
- Whether it is valid, meaning the provider is enabled and not in error
- The list of the `componentReleases` that depend on it

> It can be observed that the presence of roles is more significant in the case of the cluster deployed from scratch.
This is because the middleware deployed during the bootstrap process also uses the dependencies mechanism.

The `--dependencies` option reverses the matrix, with one line for each dependency and the role that satisfies it, 
along with its provider.

For the installation on an existing cluster:

``` shell
$ kadcli  kad roles list --dependencies
DEPENDENT         ROLES             PROVIDER          VALID
kad-webserver     ingress           _CLUSTER_         YES
redis3-commander  ingress           _CLUSTER_         YES
redis3-commander  redis3-namespace  redis3-namespace  YES
redis3-commander  redis3-redis      redis3-redis      YES
redis3-redis      redis3-namespace  redis3-namespace  YES
```

For the installation from scratch, with `kind`:

``` shell
$ kadcli kad role list --dependencies
DEPENDENT         ROLES             PROVIDER          VALID
cert-issuers      certManagerBase   cert-manager      YES
ingress-nginx     certManager       cert-issuers      YES
ingress-nginx     loadBalancer      _CLUSTER_         YES
kad-webserver     ingress           ingress-nginx     YES
redis3-commander  ingress           ingress-nginx     YES
redis3-commander  redis3-namespace  redis3-namespace  YES
redis3-commander  redis3-redis      redis3-redis      YES
redis3-redis      redis3-namespace  redis3-namespace  YES
```


## `_CLUSTER_` roles

It can be observed that the `componentRelease` `redis3-commander` depends on the roles we defined in the deployment 
(`redis3-namespace` and `redis3-redis`), but also on an `ingress` role.

> This role was defined at the `component` level. Indeed, the `componentRelease` references the `component` 
in version `0.2.0`, which differs from the previous version only by the addition of a `dependsOn: [ingress]` 
attribute. As mentioned earlier, this dependency applies to all releases of this `component`.

But, How is this ingress role provided?

In the case of the kind cluster, it is provided by the `componentRelease` `ingress-nginx`, part of the initial deployment.

However, in the case of the existing cluster, which was set up prior to KAD installation, the ingress controller 
already exists and is not managed by KAD. Therefore, KAD must consider this role as always fulfilled.

To achieve this, a boolean map named `_clusterRoles` is defined in the cluster context, specifying these types of roles.

For the existing cluster:

``` yaml
context:
 ....
  _clusterRoles:
    ingress: true
```


And for the kind cluster:

``` yaml
context:
 ....
  _clusterRoles:
    loadBalancer: true
```

> Indeed, in this last case, the `ingress-nginx` `component` depends on a `loadBalancer` role. 
However, it appears that this function is fulfilled by the `portMappings` configuration defined during the [creation of the cluster](../getting-started/130-kind.md).

These roles appear as provided by `_CLUSTER_` in the previous displays.

## Reducing latency on dependencies

By default, a `componentRelease` waiting for the deployment of a dependency will check its status every 30 seconds.

In the case of a long dependencies chain, this delay can become important.

It is possible to reduce this interval by adding an argument when launching the `helmRelease` controller.

To do this, you need to add a patch in the associated deployment by modifying the following file:


???+ abstract "clusters/kadtestX/flux/flux-system/kustomization.yaml"
    
    ``` { .yaml }
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
    - gotk-components.yaml
    - gotk-sync.yaml
    ```

Which becomes:

???+ abstract "clusters/kadtestX/flux/flux-system/kustomization.yaml"

    ``` { .yaml }
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
    - gotk-components.yaml
    - gotk-sync.yaml
    patches:
      - patch: |
          - op: add
            path: /spec/template/spec/containers/0/args/-
            value: --requeue-dependency=5s
        target:
          kind: Deployment
          name: "(kustomize-controller|helm-controller)"
    ```

It is also possible to integrate this modification into the repository used for the bootstrap, in which case it will be applied automatically.


