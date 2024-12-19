# Component




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