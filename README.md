# Steam Workshop DevOps

This project contains reusable workflows to upload a mod to the Steam workshop.

- **[General Information](./docs/index.md)**


## Supported games

Currently supported:
- **[Project Zomboid](./docs/project-zomboid/index.md)**


## Publish

### New Version

```
git tag v1.x.x
git push origin v1.x.x
```

### Update Version

```
git tag -f v1
git push origin v1 --force
```