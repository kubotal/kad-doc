# Components

## Overview


???+ example "podinfo-1.0.0.yaml"

    ``` {.yaml .copy}
    components:
      - name: podinfo
        version: 1.0.0
        source:
          defaultVersion: 6.7.1
          helmRepository:
            url: https://stefanprodan.github.io/podinfo
            chart: podinfo
        parameters:
          ingressName: # TBD
        dependsOn:
          - ingress
        values: |
          ingress:
            enabled: true
            className: nginx
            annotations:
              cert-manager.io/cluster-issuer: {{ .Context.certificateIssuer.public }}
            hosts:
              - host: {{ .Parameters.ingressName }}.{{ .Context.ingress.url }}
                paths:
                  - path: /
                    pathType: ImplementationSpecific
            tls:
              - secretName: {{ .Meta.componentRelease.name }}-tls
                hosts:
                  - {{ .Parameters.ingressName }}.{{ .Context.ingress.url }}
    ```




``` {.yaml}
Context:
  ....
  ingress:
    url: ingress.mycluster.mydomain.com
   
  certificateIssuer:
    public: company-issuer
    internal: cluster-internal
  ....

```

## properties


#### name

#### version

The version of the component. We strongly suggest to use semantic versioning: MAJOR.MINOR.PATCH

#### catalogs

#### usage

#### config

#### suspended

#### protected

#### source.allowedVersions

#### source.defaultVersion

#### source.gitRepository

#### source.ociRepository

#### source.helmRepository

#### parameters

#### parametersSchema

#### contextSchema

#### values

#### allowValues

#### allowCreateNamespace

#### roles

#### dependsOn

### gitRepository

#### source.gitRepository.name

#### source.gitRepository.path

#### source.gitRepository.path

#### source.gitRepository.unmanaged

#### source.gitRepository.namespace

### ociRepository

#### source.ociRepository.url

#### source.ociRepository.insecure

#### source.ociRepository.interval

#### source.ociRepository.secretRef

#### source.ociRepository.certSecretRef

### helmRepository

#### source.helmRepository.url

#### source.helmRepository.chart

#### source.helmRepository.interval

#### source.helmRepository.secretRef

#### source.helmRepository.certSecretRef


