

The GIT API of KAD use the credential set up by Flux for its own git access.

As we want to be able to push deployments in GIT, we need RW access.

Flux provides several methods to authenticate to GIT for both Gitlab and kenGithub.

## Github

### ssh key

Same as Gitlab 

This is de default method. Flux create an ssh 'Deploy key' for its usage, associated to the repository.

By default, this key is RO. As we want to use it for KAD, we must set the '--read-write-key' on the bootstrap command.

### Auth-token

This is an alternate method you can use by setting the '--token-auth' flag on 'flux bootstrap github....'

In such case, the GITHUB_TOKEN you provided on the bootstrap is stored by Flux in the flux-system:flux-system secret 
for its usage. As KAD will also use it for its GIT API, this token must allow RW access to the repository

## Gitlab

### ssh key

Same as Github

This is de default method. Flux create an ssh 'Deploy key' for its usage, associated to the repository.

By default, this key is RO. As we want to use it for KAD, we must set the '--read-write-key' on the bootstrap command.


### Deploy token

We advise against using this method as it prevents KAD to write to Git.

This is an alternate method you can use by setting the '--deploy-token-auth' flag on 'flux bootstrap gitlab....'

In such case, Flux create a 'Deploy Tokens'. But, there is no way to set this token RW. (AFAIK, such token can't have
write permission on target repository).


### Auth-token

(Same as Git)

This is another alternate method you can use by setting the '--token-auth' flag on 'flux bootstrap gitlab....'

In such case, the GITLAB_TOKEN you provided on the bootstrap is stored by Flux in the flux-system:flux-system secret
for its usage. As KAD will also use it for its GIT API, this token must allow RW access to the repository



