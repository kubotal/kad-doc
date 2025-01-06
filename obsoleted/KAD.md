
# KAD: Kubernetes Application Deployer

KAD is a tool aimed to ease and automate application deployment. By 'application' we understand everything on top of a
raw, bare Kubernetes cluster. This means not only your last nice web-app, but also middleware and kubernetes extension
such as ingress, cert-manager, any K8s operator, etc...  In short, anything which is installable using an Helm Chart.



## Stakeholders

Application deployment means application configuration, And this may be a complex task, as it combine input from
organization policies and pattern, technical context, application requirement and end-user wishes.

KAD will involve two type of actors:

- KAD User, witch will deploy applications easily, by providing few, simple and understandable configuration values.

- KAD Administrator which will setup the rules to merge user's config with other input such as target context, 
organization pattern and usage, external system, etc...

Even for KAD administrator, there will be a great benefit to avoid repetitive task by the automation of deployment
in several environments.


## Main concepts

Here is a short description of each object/entity defined by KAD.

To refer to the stakeholders above, the KAD User will handle only 'deployment' entities, while the KAD Administrator will
handle all others.

### Component

A component is an application, a package aimed to be deployed in some cluster. 

A component is made of one or several modules

Technically speaking, a module is a wrapper around a Helm chart. 

### Deployment

A deployment is the instantiation of a Component on a target cluster.

A deployment is configured with a set of variables, provided by the context, the component, or the deployment itself

Technically speaking, a 'deployment' will generate one fluxCD object of kind 'HelmRelease' for each module of the 
associated Component.

### Context

The Context is a set of variables bound to the target cluster.

The context can be defined through a hierarchy of embedding entities. For example, a cluster belong to an
infrastructure, which belong to an infrastructure type (OpenStack, AWS, GCP,...) which belong to an organization.

Each level can enrich the Context with its own specific variable.

It is up to the KAD Administrator to define this hierarchy. 

### Source

A source is a repository of Helm chart. Technically speaking a source is a FluxCD object of kind 'HelmRepository' or 'GitRepository' 

Each module of a deployment refers to a source.

### Template

A template is a text file with special tags allowing variable insertion. Such operation is called template rendering.

KAD use the same template engine (thus the same syntax) then Helm templating system. So, you can refer to the Helm 
documentation for more information.

There is a KAD object 'template' which host the template text itself and a 'config' field aimed to host a set of default 
values. It can also be used to document all variables to be set by a specific comment (example: `url: # TBD` for To Be Defined)

A 'template' object will host templates for HelmRelease, GitRepository and HelmRepository manifest

Besides this, some properties of Components and Deployment can also contains a template.

## Configuration files and Sources.

The entities described above are defined as object in yaml. Theses objects are defined in one or several yaml files, 
named kadFiles in the following.

These kadFiles are stored in one or several 'GitRepository' FluxCD sources. Theses sources are called 'Primary source' 
to distinguish from 'standard' sources, defined in kadFiles.

Primary sources and related kadFiles list are part of the initial configuration of the KAD system.

In most cases, there will be a single primary source, which is the 'flux-system' source, the root of FluxCD configuration.

## Template rendering and data Model for Deployment

Here, we will describe how the HelmTemplates are generated.

The entry point in a 'deployment'. This deployment refers to a 'component' which host a list of 'modules'. 
An 'HelmTemplate' (A FluxCD object) is to be generated for each module.

Each module refers to a 'template' object, looking like the following (Some parts has been removed for concision):

```
templates:
  - name: helmRelease
    template: |
      ---
      apiVersion: helm.toolkit.fluxcd.io/v2beta2
      kind: HelmRelease
      metadata:
        name: {{ .Meta.release.name }}
        namespace: flux-system
      spec:
        interval: {{ .Config.interval }}
        serviceAccountName: kustomize-controller
        targetNamespace: {{  .Meta.release.namespace }}
        storageNamespace: {{ .Meta.release.namespace }}
        releaseName: {{ .Meta.release.name  }}
        timeout: {{ .Config.timeout }}
        chart:
          spec:
         ........ 
        values:
        {{- toYaml .HelmValues | nindent 4 }}
    config:
      interval: "1m"
      timeout:  "5m"
      chart:
      .......
```

You may refer to the [FluxCD description of the 'HelmRelease'](https://fluxcd.io/flux/components/helm/helmreleases/) 
manifest for more information.

To render this template, one need to have a data model. Building such data model is the key point of this processing.

This data model is a map where the first level is a set of well-known keys: 'Config', 'Context', 'Vars' and 'Meta'. 

- 'Config' is intended to configure the HelmRelease itself. It is the merge of the 'component.module.config' field content 
on top of the 'template.config' field content. This will allow some properties of the template to be overwritten at 
the component level

> Merging A on top pf B means A variables will take precedence. 

- 'Context' is the merge of all 'context' object content, by respecting the order of definition. This will allow to 
setup precedence of values in a logic way (The variable defined at the cluster level will take precedence over the 
same variable defined at the infrastructure level. Which itself take precedence over the same variable defined at the 
organization level)

- 'Vars' is a set a variable intended to be used in the rendering of the 'values' part (See below). It s the result of 
the merge of the 'deployment.vars' content on top of the 'component.vars' content. Note than 'Vars' is global for a 
component, used for all modules

- 'Meta' is a set of well-known variables, reflecting some properties of the involved entities 
(deployment, component, ....). A reference will be provided later in this doc.

### Helm values templating

The rendering of an 'HelmTemplate' is a two steps process.

When deploying a configurable application using Helm, a key aspect is to provide an ad-hoc 'values.yaml' file. 
The layout of this 'values.yaml' file is defined by the original Helm chart designer, is not under our control and may 
be complex has it is designed to handle a multitude of case.

To hide this complexity, KAD will use a template to generate the deployment 'values.yaml' file. This will allow to:

- Expose to the user only a subset of relevant variables, in a friendly, user oriented way.
- Automatically fulfill variable from the context.
- Set values based on specific requirements.

This template is provided in the 'component.module.values' field. It is rendered with the model described above,

The result of the rendering is then added to the model, under the '.HelmValues' key. And the 'HelmRelease' template 
is then rendered.

### Values add on

But, there is a drawback this templating of the 'value' part.

Suppose I am a KAD power user and I want to modify a value of the original Helm chart (I know the internal of this chart). 
This value has to be exposed as a variable in the 'deployment.module.values' template.

If this is not the case, I would need to modify this 'deployment.module.values' template. But may be I am 
not entitled to do this. Or may be I don't want to pollute the deployment with a very specific case.

To overcome this, KAD provide an escape mechanism. There is a 'deployment.modules[name==moduleName].values' field 
which allow a KAD User to setup some values variables. These values will be merged on top the the rendering of the 
values template described above, just before insertion in the '.HelmValues' variable

Note this 'deployment.values' field can also be a template. This will allow, for example, setting values from the
'Context'

Note also a flag 'component.module.lockValues' (false by default) for the usage of a paranoiac KAD Administrator wanting
to forbid KAD Users to bypass its templating this way.

## Template rendering and data Model for Source

The way FluxCD sources ('GitRepository' or 'HelmRepository') are built are similar to 'HelmRelease', but more simpler.

Each source refers to a 'template' object, which host the template body and a default set of value, under the 
properties 'config'

A data model is built with the following root keys:

- 'Context': Same a for HelmRelease
-
- 'Config' is intended to configure the source itself. It is the merge of the 'source.config' field content
  on top of the 'template.config' field content. This will allow some properties of the template to be overwritten at
  the source level

- 'Meta' is a set of well-known variables, reflecting some properties of the source entities
  
Then, the template.body is rendered with this data model.

## Deployment template

There is some cases where  several deployment share a common set of values. This is typically the case where the
same component is deployed several times with almost the same configuration.

To handle this case, a deployment can be used as a set of default value, or pattern for another one.
Such deployment is called the parent.

For example, if deployment A is defined as the parent of B:

- Field 'component', 'namespace', 'enabled' and 'createNamespace' will take the value of A if not defined in B
- field 'dependsOn' will be the union of A and B list.
- field 'vars' will be the merge of A.vars on B.vars (A values will have more precedence in case of conflict)
- As 'modules.values' field may be template, they can't be merged upfront. They will be rendered separately and the results
  will be merged

In most case, a parent deployment is not intended to be instanced on its own. To explicit this, a 'abstract' flag
property is to be set.


## Namespace and multi-module deployment

When a component is made of several modules, they all will be deployed in the same namespace by default. 

If a component need to be deployed across several namespace, there is a specific mechanism to handle this. Each module
has a property 'namespacePattern' and its effective namespace will be the result of 
`Sprintf(namespacePattern, namespace)`, where `namespace` is the value provided by the deployment

The default value for this property is '%s', to use the deployment namespace unchanged

I you need more control over namespace distribution of the modules of a component, you will need to split it in 
several components

## Dependencies management

Technically, dependencies are attribute of the FluxCD 'HelmRelease' object. And, as stated before, there is a one-to-one 
matching between module and HelmRelease. 

So, saying 'Deployment A depends of deployment B' is a shortcut to say 'Each module/HelmRelease of deployment A depends of one or 
several module/HelmRelease of deployment B'

The name of this 'HelmRelease' is build from the deployment name and the module name, in the form <deploymentName>-<moduleName>

Deployment dependency is handled at two different levels:

- Intra component, where a module can depends of another one of the same component.
- Between deployment, where a deployment can depend of another one.

For the first level (intra component), defined by component.modules.dependsOn, which must refers to another module of the same component, 
only the module name must be provided.

For the second level (cross deployment), defined by 'deployment.dependsOn', the target module/HelmRelease name must be 
explicitly provided, in the form <deploymentName>-<moduleName>.

