# Steam Workshop DevOps

> ⚠️ Right now, only the [Project Zomboid profile](./project-zomboid/index.md) is currently considered production-ready. Additional game profiles will be documented as they become available. ⚠️

This repository provides reusable GitHub Actions for generating Steam Workshop metadata, validating packages, and publishing Workshop items with SteamCMD.

## Generic metadata generation

The root `metadata` action is game-independent. It treats `metadata.json` and `description.md` as the source of truth and generates both `README.md` and `workshop/workshop.txt`.

```yaml
- name: Generate Workshop metadata
  uses: community-owned-workshop/steam-workshop-devops/metadata@v1
  with:
    metadata-path: metadata.json
    description-path: description.md
    readme-template-path: tools/templates/README.md
```

The generic metadata action intentionally understands only common Steam/project fields such as name, version, authors, repository URL and Workshop settings. Game-specific files belong in profiles. For example, the Project Zomboid profile adds `mod.info` after calling the generic generator.

This separation lets games such as Scrap Mechanic use the generic metadata generator and Steam uploader without requiring an otherwise empty game profile.

## Prerequisites

Before publishing, you need:

* a published Workshop item
* a Steam account that owns the Workshop item
* a GitHub Environment containing the required secrets


## GitHub Environment

Create an environment (for example `steam`) and configure the following secrets.

| Secret              | Description                                                             |
| ------------------- | ----------------------------------------------------------------------- |
| `STEAM_USERNAME`    | Steam account name.                                                     |
| `STEAM_WORKSHOP_ID` | Numeric Steam Workshop item ID.                                         |

The workflow reads these secrets automatically.



### Password Log-in

If your Steam account has a simple login, you only need this additional secret:


| Secret              | Description                                                             |
| ------------------- | ----------------------------------------------------------------------- |
| `STEAM_PASSWORD`    | Steam account password.                                                 |


### Multi-Factor Log-in or Other Special Cases

If you can't just log in with only a username and password, you will need this instead.

| Secret              | Description                                                             |
| ------------------- | ----------------------------------------------------------------------- |
| `STEAM_CONFIG_VDF`  | Base64-encoded `config.vdf` containing the authenticated Steam session. |

## Publishing

The root action is game-independent. A caller supplies the Steam app ID, Workshop item ID, prepared content directory and generated Workshop metadata.

Project Zomboid has reusable workflows under `.github/workflows/` because GitHub requires reusable workflows to live there. They use `workflow_call`, so they do not run by themselves.

A game that needs no special packaging can call the generic actions directly. Scrap Mechanic is expected to use this path initially: generate metadata, prepare the desired content directory, then publish it with app ID `387990`.



## Using the workflow

**Example for publishing the code in `source/MyMod`:

```yaml
jobs:
  publish:
    uses: community-owned-workshop/steam-workshop-devops/.github/workflows/publish-project-zomboid.yml@v1
    with:
      mod-folder: MyMod
    secrets: inherit
```



## Workflow overview

The publish workflow performs the following steps:

1. Check out the repository.
2. Generate metadata.
3. Commit generated metadata if necessary.
4. Run automated tests.
5. Build the Workshop contents.
6. Validate the generated package.
7. Upload the Workshop item.

If validation fails, nothing is uploaded.


## Permissions

The workflow requires:

```yaml
permissions:
  contents: write
```

because generated metadata may be committed back to the repository.

## Security

The Steam account should only be used for publishing Workshop items.

> ⚠️ Never commit Steam credentials to the repository! ⚠️
> 
> Always use GitHub Environment Secrets.

