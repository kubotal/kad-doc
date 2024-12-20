
# kad-infra-doc reset

To reset the kad-infra-doc if used as working repo:

- delete `clusters/kadtest1/flux/flux-system` folder
- delete all `context.yaml` in kadtest1 and subfolders

- Reset `clusters/kadtest1/flux/kad.yaml` to:

    ```
          primarySources:
            - name: flux-system
              namespace: flux-system
              kadFiles:
                - clusters/kadtest1/deployments
                - components
            - location: /kad-controller
              kadFiles:
                - tmpl
    
    ```
- delete all entries in deploiment, excepted the one with _