
# Application stack






???+ abstract "components/stacks/redis-stack.yaml"

    ``` { .yaml }
    templates:
    
      - name: redis-stack
        version: 1.0.0
        parameters:
          id: # TBD Must be globally unique
          namespace: # Default to id
          hostname: # Default to id
          enabled: true
        body: |
          {{- $id := .Parameters.id }}
          {{- $namespace := .Parameters.namespace | default $id }}
          componentReleases:
            - name: {{ $id }}-namespace
              enabled: {{ .Parameters.enabled }}
              component:
                name: namespace
                version: 0.1.0
                parameters:
                  name: {{ $namespace }}
                  labels:
                    my.company.com/project-name: redis
                    my.company.com/project-id: {{ $id }}
              namespace: default
              roles:
                - {{ $id }}-namespace
    
            - name: {{ $id }}-redis
              enabled: {{ .Parameters.enabled }}
              component:
                name: redis
                version: 0.1.0
                parameters:
                  password: admin123
                  replicaCount: 1
              namespace: {{ $namespace }}
              roles:
                - {{ $id }}-redis
              dependsOn:
                - {{ $id }}-namespace
    
            - name: {{ $id }}-commander
              enabled: {{ .Parameters.enabled }}
              component:
                name: redis-commander
                version: 0.2.0
                parameters:
                  redis:
                    host: {{ $id }}-redis-master
                    password: admin123
                  hostname: {{ .Parameters.hostname | default $id }}
                  tls: true
              namespace: {{ $namespace }}
              dependsOn:
                - {{ $id }}-redis
                - {{ $id }}-namespace
    ```


???+ abstract "storehouse/redis-stack-45.yaml"

    ``` { .yaml }
    templateReleases:
    
      - name: redis4
        template:
          name: redis-stack
          version: 1.0.0
          parameters:
            id: redis4
    
    
      - name: redis5
        template:
          name: redis-stack
          version: 1.0.0
          parameters:
            id: redis5
            namespace: project5
            hostname: project5
    ```
    




