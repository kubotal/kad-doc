
# About KAD 'includes' features

Study is based on the minio deployment and another application, in a project.

## Using templates


project-p1.yaml

```
documents:

  - name: project-p1-config
    yaml:
      namespace: project-p1
      protected: true 


templateReleases:

  - name: p1-minio
    template:
      name: minio
      version: 2.0.0
      parameters:
        rootUser: minio
        rootPassword: minio123
      parameterFiles:
        - document: project-p1-config
        - document: minio-flavor-small

  - name: p1-otherapp
    template:
      name: otherapp
      version: 1.0.0
      parameters:
        otherParam: otherValue1        
      parameterFiles:
        - document: project-p1-config

```

project-p2.yaml

```
documents:

  - name: project-p2-config
    yaml:
      namespace: project-p2
      protected: false 


templateReleases:

  - name: p2-minio
    template:
      name: minio
      version: 2.0.0
      parameters:
        rootUser: minio
        rootPassword: minio123
      parameterFiles:
        - document: project-p2-config
        - document: minio-flavor-small-drp

  - name: p2-otherapp
    template:
      name: otherapp
      version: 1.0.0
      parameters:
        otherParam: otherValue2        
      parameterFiles:
        - document: project-p2-config

```

NB: This imply we set `additionalProperties: true` in parameterSchema

templates/minio-2.0.0.yaml

```

templates:
  - name: minio
    version: 2.0.0
    parameters:
      rootUser: # TBD
      rootPassword: # TBD
      storage:
        driveSize: # TBD
        replicas: # TBD
        drivesPerNode: 1
        pools: 1
      namespace: # TBD
      ingresses:
        console: true
        unsec: false
      protected: true
      ldap:
    parametersSchema:
      document: schema-parameters-template-minio-2.0.0
    contextSchema:
      document: schema-context-template-minio-2.0.0
    usage: |
      ....
    body: |
      componentReleases:
      - name: {{ .Meta.templateRelease.name }}
        namespace: {{ .Parameters.namespace }}
        component:
          name: minio
          version: 2.0.0
          protected: {{ .Parameters.protected }}
          parameters: 
            rootUser: {{ .Parameters.rootUser }}
            rootPassword: {{ .Parameters.rootPassword }}
            storage:
              driveSize: {{ .Parameters.storage.driveSize }}
              replicas:  {{ .Parameters.storage.replicas }}
              drivesPerNode: {{ .Parameters.storage.drivesPerNode }}
              pools: {{ .Parameters.storage.pools }}
            clusterIssuer: {{ .Context.certificateIssuer.internal }}
            storageClass: {{ .Context.storageClass.data }}
            ingresses:
            {{- if eq .Context.certificateIssuer.public .Context.certificateIssuer.internal }}
              passthrough:
                enabled: true
                url: {{ .Meta.templateRelease.name }}.{{ .Context.ingress.url }}
              alternate:
                enabled: false
            {{- else }}
              passthrough:
                enabled: true
                url: {{ .Meta.templateRelease.name }}-ptr.{{ .Context.ingress.url }}
              alternate:
                enabled: true
                url: {{ .Meta.templateRelease.name }}.{{ .Context.ingress.url }}
                clusterIssuer: {{ .Context.certificateIssuer.public }}
            {{- end }}
              console:
                enabled: {{ .Parameters.ingresses.console }}
                url: {{ .Meta.templateRelease.name }}-console.{{ .Context.ingress.url }}
                clusterIssuer: {{ .Context.certificateIssuer.public }}
              unsec:
                enabled: {{ .Parameters.ingresses.unsec }}
                url: {{ .Meta.templateRelease.name }}-unsec.{{ .Context.ingress.url }}
            {{- if .Parameters.ldap }}
            {{- toYaml (get .Context.minio.ldapSettings  .Parameters.ldap ) | nindent 6 }}
            {{- end }}          

# --------------------------------------------------------------

documents:

  - name: schema-parameters-template-minio-2.0.0
    yaml:
      $schema: "http://json-schema.org/schema#"
      type: object
      additionalProperties: false
      .....

  - name: schema-context-template-minio-2.0.0
    yaml:
      $schema: "http://json-schema.org/schema#"
      type: object
      additionalProperties: true
      required:
      ..... 
```

NB: Schema are truncated. Context schema host LDAP env config.

While context independent, component/minio-2.0.0.yaml is almost as complex as the template. 
And must also host the LDAP env definition in context schema.

## Using includes

project-p1.yaml

```
documents:

  - name: project-p1-config
    yaml:
      namespace: project-p1
      protected: true 


includes:

  - name: p1-minio
    file: minio-2.0.0.yaml
    parameters:
      rootUser: minio
      rootPassword: minio123
    parametersSchema:
      document: schema-parameters-include-minio-2.0.0
    parameterFiles:
      - document: project-p1-config
      - document: minio-flavor-small

  - name: p1-otherapp
    file: otherapp-1.0.0.yaml
    parametersSchema:
      document: schema-parameters-include-otherapp-1.0.0
    parameters:
      otherParam: otherValue        
    parameterFiles:
      - document: project-p1-config

```

project-p2.yaml

```
documents:

  - name: project-p2-config
    yaml:
      namespace: project-p2
      protected: true 


includes:

  - name: p2-minio
    file: minio-2.0.0.yaml
    parameters:
      rootUser: minio
      rootPassword: minio123
    parametersSchema:
      document: schema-parameters-include-minio-2.0.0
    parameterFiles:
      - document: project-p2-config
      - document: minio-flavor-small

  - name: p2-otherapp
    file: otherapp-1.0.0.yaml
    parametersSchema:
      document: schema-parameters-include-otherapp-1.0.0
    parameters:
      otherParam: otherValue        
    parameterFiles:
      - document: project-p1-config

```

file minio-2.0.0.yaml

```
# Need to set some comments to explain parameters
#
#    parameters:
#      rootUser: # TBD
#      rootPassword: # TBD
#      storage:
#        driveSize: # TBD
#        replicas: # TBD
#        drivesPerNode: 1
#        pools: 1
#      namespace: # TBD
#      ingresses:
#        console: true
#        unsec: false
#      protected: true
#      ldap:

componentReleases:
- name: {{ .Meta.templateRelease.name }}
  namespace: {{ .Parameters.namespace }}
  component:
    name: minio
    version: 2.0.0
    protected: {{ .Parameters.protected }}
    parameters: 
      rootUser: {{ .Parameters.rootUser }}
      rootPassword: {{ .Parameters.rootPassword }}
      storage:
        driveSize: {{ .Parameters.storage.driveSize }}
        replicas:  {{ .Parameters.storage.replicas }}
        drivesPerNode: {{ .Parameters.storage.drivesPerNode }}
        pools: {{ .Parameters.storage.pools }}
      clusterIssuer: {{ .Context.certificateIssuer.internal }}
      storageClass: {{ .Context.storageClass.data }}
      ingresses:
      {{- if eq .Context.certificateIssuer.public .Context.certificateIssuer.internal }}
        passthrough:
          enabled: true
          url: {{ .Meta.templateRelease.name }}.{{ .Context.ingress.url }}
        alternate:
          enabled: false
      {{- else }}
        passthrough:
          enabled: true
          url: {{ .Meta.templateRelease.name }}-ptr.{{ .Context.ingress.url }}
        alternate:
          enabled: true
          url: {{ .Meta.templateRelease.name }}.{{ .Context.ingress.url }}
          clusterIssuer: {{ .Context.certificateIssuer.public }}
      {{- end }}
        console:
          enabled: {{ .Parameters.ingresses.console }}
          url: {{ .Meta.templateRelease.name }}-console.{{ .Context.ingress.url }}
          clusterIssuer: {{ .Context.certificateIssuer.public }}
        unsec:
          enabled: {{ .Parameters.ingresses.unsec }}
          url: {{ .Meta.templateRelease.name }}-unsec.{{ .Context.ingress.url }}
      {{- if .Parameters.ldap }}
      {{- toYaml (get .Context.minio.ldapSettings  .Parameters.ldap ) | nindent 6 }}
      {{- end }}          

```

Schema document are same as template version

## template vs include

- Same number of files.
- parameters/context schema must be associated to each include instance instead of be bound to the template itself
- With include, we lost parameters documentation and default values.
- If we want to simplify by dropping parameters description and schema template become almost as simple as the
included file:

```

templates:
  - name: minio
    version: 2.0.0
    body: |
      componentReleases:
      - name: {{ .Meta.templateRelease.name }}
        namespace: {{ .Parameters.namespace }}
        component:
          name: minio
          version: 2.0.0
          protected: {{ .Parameters.protected }}
          parameters: 
            rootUser: {{ .Parameters.rootUser }}
            rootPassword: {{ .Parameters.rootPassword }}
            storage:
              driveSize: {{ .Parameters.storage.driveSize }}
              replicas:  {{ .Parameters.storage.replicas }}
              drivesPerNode: {{ .Parameters.storage.drivesPerNode }}
              pools: {{ .Parameters.storage.pools }}
            clusterIssuer: {{ .Context.certificateIssuer.internal }}
            storageClass: {{ .Context.storageClass.data }}
            ingresses:
            {{- if eq .Context.certificateIssuer.public .Context.certificateIssuer.internal }}
              passthrough:
                enabled: true
                url: {{ .Meta.templateRelease.name }}.{{ .Context.ingress.url }}
              alternate:
                enabled: false
            {{- else }}
              passthrough:
                enabled: true
                url: {{ .Meta.templateRelease.name }}-ptr.{{ .Context.ingress.url }}
              alternate:
                enabled: true
                url: {{ .Meta.templateRelease.name }}.{{ .Context.ingress.url }}
                clusterIssuer: {{ .Context.certificateIssuer.public }}
            {{- end }}
              console:
                enabled: {{ .Parameters.ingresses.console }}
                url: {{ .Meta.templateRelease.name }}-console.{{ .Context.ingress.url }}
                clusterIssuer: {{ .Context.certificateIssuer.public }}
              unsec:
                enabled: {{ .Parameters.ingresses.unsec }}
                url: {{ .Meta.templateRelease.name }}-unsec.{{ .Context.ingress.url }}
            {{- if .Parameters.ldap }}
            {{- toYaml (get .Context.minio.ldapSettings  .Parameters.ldap ) | nindent 6 }}
            {{- end }}          

```

IMO, include is useless

# Templating stack

One can see the project as a 'stack'. So templating this by another level.

- One template for defining the stack
- One template to inject the context properties as parameters
- The final component 

This means three level hosting each a parameters set definition and schema. Hard to debug and maintain.

Using the initial approach where the injection of the context is performed at the component level suppress on level of
templating and offer, IMO, a far more cleaner separation of concern:
- The integration component/context is at the component level
- The integration between components is at the stack level

Example:

https://github.com/kubotal/kad-infra-sa/blob/work2/projects/projectA.yaml

https://github.com/kubotal/kad-infra-sa/blob/work2/clusters/kind/mbp64/kubo4/deployments/projectA-1.yaml

