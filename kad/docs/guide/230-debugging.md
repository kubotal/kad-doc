# Debugging

What to do when things don't work as expected?

## Example 1

To illustrate this scenario, an error can be triggered by commenting out the `component.parameters.clusterIssuer` 
attribute of `podinfo2`, while leaving the `tls` flag set to `true`.

Once this modification is propagated, you will notice that the READY status of the container included in the 
`kad-controller` pod is set to 0.

``` bash
$ kubectl get pods -n flux-system
NAME                                       READY   STATUS    RESTARTS      AGE
helm-controller-6f558f6c5d-pk5v9           1/1     Running   1 (93m ago)   2d1h
kad-controller-5459b95498-zb8rz            0/1     Running   0             19m
kustomize-controller-74fb56995-dq4c8       1/1     Running   1 (93m ago)   2d1h
notification-controller-5d794dd575-bqm8b   1/1     Running   1 (93m ago)   2d1h
source-controller-6d597849c8-djq46         1/1     Running   1 (93m ago)   2d1h
```

Examining the logs of the kad-controller pod will reveal the following error:

``` bash
$ kubectl logs -n flux-system kad-controller-5459b95498-zb8rz
....
time="2024-12-20T11:36:47Z" level=info msg="-- RECONCILER --" logger=watcherReconciler object="flux-system:flux-system"
time="2024-12-20T11:36:47Z" level=info msg="Source #0" logger=watcherReconciler source.location=/work/watcher/primary-sources/flux-system source.name=flux-system source.namespace=flux-system
time="2024-12-20T11:36:47Z" level=info msg="Source #1 is local" logger=watcherReconciler
time="2024-12-20T11:36:47Z" level=info msg=Apply apiVersion=source.toolkit.fluxcd.io/v1 dryRun=false kind=HelmRepository name=https---stefanprodan-github-io-podinfo-1h-unpr namespace=flux-system
time="2024-12-20T11:36:47Z" level=info msg=Apply apiVersion=helm.toolkit.fluxcd.io/v2 dryRun=false kind=HelmRelease name=podinfo1 namespace=flux-system
time="2024-12-20T11:36:47Z" level=info msg=Apply apiVersion=source.toolkit.fluxcd.io/v1 dryRun=false kind=HelmRepository name=https---stefanprodan-github-io-podinfo-1h-unpr namespace=flux-system
time="2024-12-20T11:36:47Z" level=info msg="Reconciliation finished with 2 error(s)" count=2 logger=watcherReconciler
time="2024-12-20T11:36:47Z" level=info msg=Error error="error on applying componentRelease 'podinfo2' componentRelease[podinfo2] (file:/work/watcher/primary-sources/flux-system/clusters/kadtest1/deployments/podinfo2.yaml, path:/): error while building model: component[podinfo:0.2.0] (file:/work/watcher/primary-sources/flux-system/components/apps/podinfo-0.2.0.yaml, path:/): error on 'values' property: error while rendering tmpl: template: :6:39: executing \"\" at <required \"`.Parameters.clusterIssuer` must be defined if tls: true\" .Parameters.clusterIssuer>: error calling required: `.Parameters.clusterIssuer` must be defined if tls: true\n" logger=watcherReconciler
time="2024-12-20T11:36:47Z" level=info msg=Error error="cleaner is enabled in configuration but clenup can't be performed with errors" logger=watcherReconciler
time="2024-12-20T11:36:54Z" level=info msg="healthz check failed" logger=controller-runtime.healthz statuses="[{}]"
```
This is an error at the KAD level. The consequence is that KAD is unable to generate a new version of the `helmRelease` object. 
If it is an update, the previous version will remain untouched, and the application will remain unchanged.

## Example 2

It is also possible that everything is correct at the KAD level, but the error lies within the deployment itself.

To simulate this scenario, you can restore the definition of the `component.parameters.clusterIssuer` attribute 
and comment out the definition of the `fqdn` parameter.

After committing and pushing the changes to Git, and after a propagation delay, you will notice that there is no longer 
an error in the `kad-controller` pod.

``` bash
$ kubectl get pods -n flux-system
NAME                                       READY   STATUS    RESTARTS        AGE
helm-controller-6f558f6c5d-pk5v9           1/1     Running   1 (3h30m ago)   2d3h
kad-controller-5459b95498-zb8rz            1/1     Running   0               135m
kustomize-controller-74fb56995-dq4c8       1/1     Running   1 (3h30m ago)   2d3h
notification-controller-5d794dd575-bqm8b   1/1     Running   1 (3h30m ago)   2d3h
source-controller-6d597849c8-djq46         1/1     Running   1 (3h30m ago)   2d3h
```

However, the error will now appear at the level of the corresponding helmRelease resource.

``` bash
$ kubectl get helmReleases -n flux-system
NAME             AGE    READY   STATUS
kad-controller   2d3h   True    Helm upgrade succeeded for release flux-system/kad-controller.v3 with chart kad-controller@0.6.0-snapshot+7fb305b8c68d
podinfo1         173m   True    Helm install succeeded for release podinfo1/podinfo1.v1 with chart podinfo@6.7.1
podinfo2         136m   False   Helm upgrade failed for release podinfo2/podinfo2 with chart podinfo@6.7.1: cannot patch "podinfo2" with kind Ingress: Ingress.networking.k8s.io "podinfo2" is invalid: spec.tls[0].hosts[0]: Invalid value: "": a lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
```

It would have been better to detect such errors earlier by replacing the first `{{.Parameters.fqdn}}` with
`{{ required "Parameters.fqdn must be defined" .Parameters.fqdn }}` in the template.

Later, the possibility of detecting such errors upstream through the use of schemas for component parameters will be discussed.

In general, in case of malfunctions, the objects to check are:

- Ths logs of the `kad-controller` pod.
- Ths Kubernetes/FluxCD `HelmReleases` resources.
- Ths Kubernetes/FluxCD `HelmRepositories` resources.
- The Kubernetes/FluxCD `GitRepositories` resources.
- The Kubernetes/FluxCD `OCIRepositories` resources.


KAD provides a CLI (Command Line Interface) tool that facilitates development and debugging. It will be discussed in a [later chapter](./250-kadcli.md)






