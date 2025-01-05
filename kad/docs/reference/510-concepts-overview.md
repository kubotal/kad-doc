
# Concepts and entities

Here is a short description of each object/entity defined by KAD.

## Component

A component is an application, a package aimed to be deployed on some cluster.

Technically speaking, a component is a wrapper around a Helm chart.

## ComponentReleases

A ComponentRelease is the instantiation of a Component on a target cluster.

A ComponentRelease is configured with a set of variables, provided as parameters and retrieved from the context.

Technically speaking, a 'componentRelease' will generate one fluxCD object of kind 'HelmRelease'.

## Context

The Context is a set of variables bound to the target cluster.

The context can be defined through a hierarchy of embedding entities. For example, a cluster belong to an
infrastructure, which belong to an infrastructure type (OpenStack, AWS, GCP,...) which belong to an organization.

Each level can enrich the Context with its own specific variable.

It is up to the KAD Administrator to define this hierarchy.

A good practice is to populate the context with only cluster specifics variables. Variables spécific to a deployment,
a team, a project, etc... are better to be provided as parameters on releases.

## Source

A source is a repository of Helm chart. It is part of the component definition. 

Technically speaking a source is a FluxCD object of kind 'HelmRepository', 'GitRepository' or OCIRepository.

## Templating

KAD make heavy usage of templating, at several level.

A template is a text file with special tags allowing variable insertion. Such variables are provided by a data structure called a 'data model'.

Template rendering is the action of merging the template with a data model, producing a new set of values.

KAD use the same template engine (thus the same syntax) than the Helm templating system. So, you can refer to the Helm
documentation for more information.

## Template

There is 'Template' KAD object. It allow to dynamically create new KAD objects, A typical use case is the creation of some 
'application stack' by grouping a set of components, and then handling them as a single entity.

## TemplateRelease

A 'TemplateRelease' is the instantiation of a 'template' object, with a specific set of parameters.

## KadFiles

The entities described above are defined as object in yaml. Theses objects are defined in one or several yaml files,
named kadFiles in the following.

These kadFiles are stored in one or several Git repositories, referenced a FluxCD source. Theses sources are called 'Primary source'
to distinguish from 'standard' sources, used by the Component objects.

Primary sources and related kadFiles list are part of the initial configuration of the KAD system.

In most cases, there will be a single primary source, which is the 'flux-system' source, the root of FluxCD configuration.

All object are consolidated by KAD in an internal data structure called the 'referential' in this documentation.

## Referential

TODO

## Loader

TODO

## Document

TODO

## Role

TODO

## Schema

TODO
