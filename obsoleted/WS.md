


https://kad-controller.mycluster.com/api/kad/v1/<clusterName>/resourceType[/resourceName]?format=[json|yaml]&action=[view|resume|full|render|apply]&label=xxxx:yyy

Default format: json

Action
- view: Object With spec and status
- full: same with all associated schema embedded 
- resume: Shorten version. Intended for list
- render: The rendered flux object (For componentRelease and gitRepository. and may be for deployment)
- apply: Rendering is pushed in K8s

Default action: view if resourceName is set. resume if not

If no resourceName => list

resume in text format may be less complete

label: filter response (And-ed if several)

'service' is a new type of object, specific to the api. It is backed by a component or a template. Aim is to hide 
this distinction for the user.
Only list is implement, with a filtering per label. 
Returned value include name, label, description and parameter schema

`label` can just provide a list of labels of component and template

Git operation will be handled specifically
https://kad-controller.mycluster.com/api/git/v1/<clusterName>/....

And kubernetes access also:
https://kad-controller.mycluster.com/api/k8s/v1/<clusterName>/helmReleases
