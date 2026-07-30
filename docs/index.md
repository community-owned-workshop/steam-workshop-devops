# Steam Workshop DevOps

> ⚠️ Right now, only the [Project Zomboid profile](./project-zomboid/index.md) is currently considered production-ready. Additional game profiles will be documented as they become available. ⚠️

This repository provides reusable GitHub workflows for publishing Steam Workshop items.

The workflow automatically validates your project, prepares the Workshop package, and uploads it using SteamCMD.


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

