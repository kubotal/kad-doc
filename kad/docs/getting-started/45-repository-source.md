

# OCI and GIT repository source

We will now proceed with the deployment of two interconnected applications:

- Redis
- Redis Commander, a frontend interface for accessing Redis.

## Redis: OCI Repository

For the Redis deployment, we use the chart provided by Bitnami. This chart is packaged as an OCI image.

> This packaging format for Helm charts is becoming increasingly common due to its flexibility and its reliance on the same infrastructure as container images.

Here is the component using This Chart:

???+ abstract "components/middleware/redis-0.1.0.yaml"
    ``` yaml
    components:
      - name: redis
        version: 0.1.0
        source:
          defaultVersion: 20.6.1
          ociRepository:
            url: oci://registry-1.docker.io/bitnamicharts/redis
        allowCreateNamespace: true
        parameters:
          password: # TBD
          replicaCount: 1
        values: |
          fullnameOverride: {{ .Meta.componentRelease.name }}
          global:
            redis:
              password: {{ .Parameters.password }}
          master:
            persistence:
              enabled: false
          replica:
            persistence:
              enabled: false
            replicaCount: {{ .Parameters.replicaCount }}      
    ```

Key notes:

- The source type is `ociRepository`. The only parameters required are the image URL and its version (used as `tag`).
- For simplicity in this example, Redis persistence is disabled.
- The `fullnameOverride` variable in the `values` block defines a prefix for naming all deployed resources. 
  By default, it combines the chart name and release name. To ensure predictability, it is overridden 
  with the name of our deployment.

## Redis Commander: Git Repository

In addition to Redis, we want to deploy the Redis Commander tool.

The authors of Redis Commander provide a Helm chart in their GitHub repository. However, this chart is not published as an OCI image or in a Helm repository.

Fortunately, FluxCD and KAD allow us to use a Helm chart directly from a Git repository. To achieve this, we need to use a `gitRepository` KAD object.

This object, along with the redis-commander component, can be found in the following file:

???+ abstract "components/middleware/redis-commander-0.1.0.yaml"

    ``` yaml
    gitRepositories:
    
      - name: redis-commander
        ref:
          branch: master
        url: https://github.com/joeferner/redis-commander.git
        ignore: |
          # exclude all
          /*
          # include helm chart dir
          !/k8s/helm-chart/redis-commander
    
    components:
    
    - name: redis-commander
      version: 0.1.0
      source:
        defaultVersion: 0.6.0
        gitRepository:
          name: redis-commander
          path: k8s/helm-chart/redis-commander
      parameters:
        redis:
          password: # TBD
          host: redis-master
        tls: false
        hostname: # TBD
      values: |
        redis:
          host: {{ .Parameters.redis.host }}
          password: {{ .Parameters.redis.password }}
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
                - "/"
          {{- if .Parameters.tls }}
          tls:
            - secretName: {{ .Meta.componentRelease.name }}-tls
              hosts:
                - {{ .Parameters.hostname }}.{{ .Context.ingress.hostPostfix }}
          {{- end }}
    ```


Key notes:

- The `ref` sub-element can refer to a branch (as in this example), a `tag`, a `commit` ID, a `semver`, or a `name`. 
  See the [FluxCD documentation](https://fluxcd.io/flux/components/source/api/v1/#source.toolkit.fluxcd.io/v1.GitRepositoryRef) for details.
- FluxCD archives the repository's content locally. To reduce the load, this archiving can be restricted to the 
  necessary files using the `ignore` attribute, which uses `.gitignore`-style syntax.
- The component leverages the `context` defined earlier. It must be properly set.

### The FluxCD `gitRepository` Object

Examining the list of `gitRepository` resources:

```
$ kubectl -n flux-system get gitRepository
NAME              URL                                                AGE   READY   STATUS
flux-system       ssh://git@github.com/kubotal/kad-infra-doc         15d   True    stored artifact for revision 'main@sha1:e8788571eb8c2a7f642e0c90293a3ef8e3f3feb1'
redis-commander   https://github.com/joeferner/redis-commander.git   12h   True    stored artifact for revision 'master@sha1:a92d4d2424e527aee938af98448686c205e3df45'
```

We find:

- Our redis-commander repository.
- The initial Git repository created during the Flux bootstrap process.

## Deployment

Here is a first deployment of the stack:

???+ abstract "storehouse/redis-stack-1.yaml"

    ``` yaml
    componentReleases:
    
      - name: redis1-redis
        component:
          name: redis
          version: 0.1.0
          config:
            install:
              createNamespace: true
          parameters:
            password: admin123
            replicaCount: 1
        namespace: redis1
    
      - name: redis1-commander
        component:
          name: redis-commander
          version: 0.1.0
          parameters:
            redis:
              host: redis1-redis-master
              password: admin123
            hostname: redis1
            tls: true
        namespace: redis1
    ```

Key notes:

- The `password` secures communication between Redis and Redis Commander. It must be identical on both sides.

    > Providing the password as a parameter means it will be stored in Git, which is not acceptable in a production 
    environment. But, implementing a secure solution is outside the scope of this document.

- The `redis.host` parameter in Redis Commander corresponds to the kubernetes `service` associated with the Redis master.
- The `hostname` parameter is the access prefix for our instance. Therefore, we will be able to connect to the URL 
  `redis1.ingress.kadtestX.k8s.local`, provided that the name is correctly configured in the DNS being used.

This deployment file is located in the `storehouse` directory, which is NOT included in the `kadFiles` list defined 
in the KAD configuration. As a result, it is ignored by KAD

To proceed with the actual deployment, simply copy this file into the deployment directory of your cluster 
(`clusters/kadTestX/deployments`), where it will be automatically processed by KAD.

Note that since the components use the `context`, this deployment is independent of the target cluster (But your 
`context` must be properly set, as defined in previous chapter)

If everything goes well, three new `pods` should be created:

```
$ kubectl -n redis1 get pods
NAME                                                READY   STATUS    RESTARTS      AGE
redis1-commander-redis-commander-68f8dfcd75-xvsj2   1/1     Running   0             37h
redis1-redis-master-0                               1/1     Running   0             37h
redis1-redis-replicas-0                             1/1     Running   2 (15h ago)   37h

```

As well as an `ingress` allowing access to Redis Commander:

```
$ kubectl -n redis1 get ingress
NAME                               CLASS   HOSTS                               ADDRESS         PORTS     AGE
redis1-commander-redis-commander   nginx   redis1.ingress.kadtest1.k8s.local   192.168.56.11   80, 443   37h
```

> Don't forget to configure the corresponding DNS entry.


We can also view the Kubernetes `services` created for Redis, with `redis1-redis-master` being the one used by Redis Commander.

```
$ kubectl -n redis1 get services
NAME                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
redis1-commander-redis-commander   ClusterIP   10.233.15.94    <none>        80/TCP     37h
redis1-redis-headless              ClusterIP   None            <none>        6379/TCP   37h
redis1-redis-master                ClusterIP   10.233.14.140   <none>        6379/TCP   37h
redis1-redis-replicas              ClusterIP   10.233.14.179   <none>        6379/TCP   37h
```

## The namespace Creation

The namespace for these components is created by the first component deployed. However, there is no guarantee regarding the creation order.

Additionally, namespaces created as a side effect of deploying a Helm chart cannot be customized (e.g., adding `labels` or `annotations`).

A best practice for deploying an application stack is to explicitly create the namespace with desired characteristics. 
This approach also allows adding resources such as `serviceAccounts`, `roles`, `roleBindings`....

For this purpose, a small Helm chart can be created, which can either be generic or specific to our application.

Such a chart is provided in the `charts/namespace/1.0.0` directory of our Git repository. It enables the creation of a 
namespace with optional parameters for labels and annotations. Note the convention that allows us to version this chart.

Here is a first version of the component using this chart, along with the associated `gitRepository`:

???+ abstract "components/apps/_namespace-0.0.5.yaml"

    ``` { .yaml }
    gitRepositories:
    
      - name: kad-infra-doc
        watched: true
        interval: 30s
        protected: true
        ref:
          branch: main
        url: https://github.com/kubotal/kad-infra-doc.git
    
    components:
    
    - name: namespace
      version: 0.0.5
      source:
        defaultVersion: 1.0.0
        gitRepository:
          name: kad-infra-doc
          path: charts/namespace/{version}
      parameters:
        name: # TBD
        labels: {}
        annotations: {}
      values: |
        {{ toYaml .Parameters }
    ```

However, we won't be using this version. In fact, our Git repository is already referenced by FluxCD during the 
bootstrap process. (Its definition is located in the file `clusters/kadtestX/flux/flux-system/gotk-sync`).

As previously mentioned, a `gitRepository` consumes some resources, so it is advisable to avoid duplicating them.

We will therefore use:

???+ abstract "components/apps/namespace-0.1.0.yaml"

    ``` { .yaml }
    components:
    
    - name: namespace
      version: 0.1.0
      source:
        defaultVersion: 1.0.0
        gitRepository:
          name: flux-system
          namespace: flux-system
          unmanaged: true
          path: charts/namespace/{version}
      parameters:
        name: # TBD
        labels: {}
        annotations: {}
      values: |
        {{ toYaml .Parameters }}
    ```

Key points:

- The gitRepository object is not managed by KAD since it is under direct FluxCD control (`source.gitRepository.unmanaged: true`).
- The `namespace` of this gitRepository FluxCD resources must be specified (`source.gitRepository.namespace`).
- Versioning is managed by substituting the `{version}` token in the path if present.

Another advantage of using this `gitRepository` is that its authentication is already managed by FluxCD. 
In contrast, the first example only works if the Git repository is public (adding authentication information is 
possible but is described later in this manual).

### Deployment

Here's a new version of the deployment, using this last component.

???+ abstract "storehouse/redis-stack-2.yaml"

    ``` { .yaml }
    componentReleases:
    
      - name: redis2-namespace
        component:
          name: namespace
          version: 0.1.0
          parameters:
            name: redis2
            labels:
              my.company.com/project-name: redis
              my.company.com/project-id: redis2
        namespace: default
    
      - name: redis2-redis
        component:
          name: redis
          version: 0.1.0
          parameters:
            password: admin123
            replicaCount: 1
        namespace: redis2
    
      - name: redis2-commander
        component:
          name: redis-commander
          version: 0.1.0
          parameters:
            redis:
              host: redis2-redis-master
              password: admin123
            hostname: redis2
            tls: true
        namespace: redis2
    ```

As previously mentioned, simply copy this file into the deployment directory of your cluster 
(`cluster/kadTestX/deployments`), where it will automatically be processed by KAD, which will then handle its deployment.

If everything goes well, three new `pods` should be created:

```
$ kubectl -n redis2 get pods
NAME                                                READY   STATUS    RESTARTS      AGE
redis2-commander-redis-commander-58f7b5c54f-r4xdq   1/1     Running   0             24h
redis2-redis-master-0                               1/1     Running   0             24h
redis2-redis-replicas-0                             1/1     Running   2 (15h ago)   24h

```

You can also validate that the labels have been correctly created for the namespace:

```
$ kubectl get namespace redis2 -o yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    meta.helm.sh/release-name: redis2-namespace
    meta.helm.sh/release-namespace: default
  creationTimestamp: "2025-01-02T09:32:18Z"
  labels:
    app.kubernetes.io/managed-by: Helm
    helm.toolkit.fluxcd.io/name: redis2-namespace
    helm.toolkit.fluxcd.io/namespace: flux-system
    kubernetes.io/metadata.name: redis2
    my.company.com/project-id: redis2
    my.company.com/project-name: redis
  name: redis2
  resourceVersion: "1743401"
  uid: 9523a057-81b5-4dcb-a2d1-983ca4afeff8
spec:
  finalizers:
  - kubernetes
status:
  phase: Active

```

### Removal

To delete our stack, you simply need to remove the corresponding file in the `deployment` directory. 

One of the consequences of explicitly creating the namespace as a `component` is that it will also be deleted.

If this behavior is considered risky, several safeguards
can be implemented. A [dedicated chapter](./xxxxx.md) is provided to cover this aspect in detail.


