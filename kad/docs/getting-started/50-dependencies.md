





``` shell
$ kadcli k8s helmRelease list
NAME              READY  STATUS                                                                                                                  AGE
.....
redis3-commander  False  dependency 'flux-system/redis3-redis' is not ready                                                                      2s
redis3-namespace  True   Helm install succeeded for release default/redis3-namespace.v1 with chart namespace@1.0.0+e8788571eb8c                  3s
redis3-redis      False  dependency 'flux-system/redis3-namespace' is not ready
```




``` shell
$ kadcli k8s helmRelease list
NAME              READY    STATUS                                                                                                                  AGE
.....
redis3-commander  False    dependency 'flux-system/redis3-redis' is not ready                                                                      35s
redis3-namespace  True     Helm install succeeded for release default/redis3-namespace.v1 with chart namespace@1.0.0+e8788571eb8c                  36s
redis3-redis      Unknown  Running 'install' action with timeout of 3m0s
```


``` shell
$ kadcli k8s helmRelease list
NAME              READY  STATUS                                                                                                                  AGE
.....
redis3-commander  True   Helm install succeeded for release redis3/redis3-commander.v1 with chart redis-commander@0.6.0+e8788571eb8c             4m38s
redis3-namespace  True   Helm install succeeded for release default/redis3-namespace.v1 with chart namespace@1.0.0+e8788571eb8c                  4m39s
redis3-redis      True   Helm install succeeded for release redis3/redis3-redis.v1 with chart redis@20.6.1+55659cf4e324
```
