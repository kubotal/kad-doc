# Preparation

## Creating the GitHub Repository

The first step is to create a dedicated GIT repository to host your cluster configuration.

> Note that his repository will be capable of accommodating multiple clusters, potentially encompassing the entirety of your infrastructure.

The easiest way to do this is to start from [GitHub template we provide](https://github.com/kubotal/kad-infra-doc).

Click on the green button located on the top right of the page: `Use this template` and `Create a new repository`.

You can create this new repository in your personal GitHub account or within one of your organizations. It can be public or private.

Some of the following steps may involve modifying the content of this repository

- This can be done by cloning it, editing its content, and then committing and pushing the changes.
- Alternatively, this can also be done directly on GitHub.

## Installing the FluxCD CLI Client

You'll need to install the FluxCD client on your workstation to proceed with its installation. Please refer to the [corresponding FluxCD documentation for detailed instructions](https://fluxcd.io/flux/get-started/#install-the-flux-cli).

## Installation types

Next, there are two variants of this installation, depending on your environment:

- [On an existing cluster](./installation-existing-cluster.md): This requires having an operational cluster, including an Ingress controller, suitable for this type of testing. This cluster must also have Internet access.
- From scratch: Using Kind allows you to create a minimal cluster, which will then be enhanced by KAD with a set of extensions (Cert-manager, ingress, etc.).

As the first option is slightly more gradual, we encourage you to start with it if possible.