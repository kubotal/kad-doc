
# Scoped context

Let's say we want an url suffix different for each team. 

Each kad file can have a 'scope' entry:

```
scope: team1

context: 
  ingress:
    url: ingress.team1

componentReleases:
  
  - name: web-team1-app1
    namespace: team1
    component:
      name: webapp
      version: 1.0.0
      
```

Context information will be specific to scope 'team1'

All release (template or components) included in the files will see a context resulting from the marge of the 'base' 
one and the one specific of the context

One may also split the files:


```
scope: team2

context: 
  ingress:
    url: ingress.team2
    
```

```
scope: team2

componentReleases:
  
  - name: web-team2-app1
    namespace: team2
    component:
      name: webapp
      version: 1.0.0
      
```

Also, scope can be set on the release itself

```
componentReleases:

  - name: web-team1-app1
    scope: team1
    namespace: team1
    component:
      name: webapp
      version: 1.0.0

  
  - name: web-team2-app1
    scope: team2
    namespace: team2
    component:
      name: webapp
      version: 1.0.0

```

# Multi scope:

Problem: we need several 'axes' of context. For example, by team and by environment.

'scope' can become a list 'scopes'

```
scopes: [team1]

context: 
  ingress:
    url: ingress.team1
```

```
scopes: [team2]

context: 
  ingress:
    url: ingress.team2
```

```
scopes: [env_dev]

context: 
  debug: true
```

```
scopes: [env_prd]

context: 
  debug: false
```

```
scopes: [team1, env_dev]

componentReleases:
  
  - name: web-team1-app1-dev
    namespace: team1
    component:
      name: webapp
      version: 1.0.0
      
```

or 

```
componentReleases:
  
  - name: web-team1-app1-dev
    scopes:
      - team1
      - env_dev
    namespace: team1
    component:
      name: webapp
      version: 1.0.0
      
```

# Multi doc reader

Let's say we want to define several context in the same file:

```
scopes: [team1]

context: 
  ingress:
    url: ingress.team1

scopes: [team2]

context: 
  ingress:
    url: ingress.team2
```

This will not works, as each file must be a valid yaml file.

Solution would be to use the multi-docs reader:

```
---
scopes: [team1]

context: 
  ingress:
    url: ingress.team1
---
scopes: [team2]

context: 
  ingress:
    url: ingress.team2
```







