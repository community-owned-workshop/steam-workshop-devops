## Steam Workshop DevOps - Project Zomboid

- you can use the [Project Zomboid Template](https://github.com/community-owned-workshop/project-zomboid-template)
- or you can take a look at an [example project](https://github.com/community-owned-workshop/project-zomboid-characters)


### Validate pull requests

```yaml
name: Validate Pull Request

on:
  pull_request:
    branches: [main]
  workflow_dispatch:  # allows manually publishing a release without merging a pull request

permissions:
  contents: read

jobs:
  validate:
    uses: community-owned-workshop/steam-workshop-devops/.github/workflows/validate-project-zomboid.yml@v1
    with:
      mod-folder: MyMod
```

This validates scripts and JSON, generates metadata, runs Lua tests and checks the Project Zomboid Workshop package.


## Publish after a merge

```yaml
name: Publish to Steam Workshop

on:
  workflow_dispatch: # allows manually publishing a release without merging a pull request
  pull_request_target:
    branches: [main]
    types: [closed]

permissions:
  contents: read

jobs:
  publish:
    if: >
      github.event_name == 'workflow_dispatch' ||
      github.event.pull_request.merged == true
    permissions:
      contents: write
    uses: community-owned-workshop/steam-workshop-devops/.github/workflows/publish-project-zomboid.yml@v1
    with:
      branch: main
      mod-folder: MyMod
      changelog: ${{ github.event.pull_request.title || 'Manual Workshop update' }}
    secrets: inherit
```


## Required environment

_See [general information](../index.md#github-environment)_
