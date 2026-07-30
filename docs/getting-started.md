# Getting Started


#### 1. Create your repository

- Click **[Use this template](https://github.com/community-owned-workshop/project-zomboid-template/generate)**.


#### 2. Install Lua and Test Framework

- execute `./tools/setup.ps1`
- sanity check this template by executing `./tools/test.ps1` - if this doesn't work the template is broken and you should [create a Bug Report](https://github.com/community-owned-workshop/project-zomboid-template/issues/new?template=bug_report.yml)
- the correct output should look like this

```
# last lines of setup.ps1:

Setup completed.
Run tests with: .\tools\test.ps1


# run tests:

PS C:\git\project-zomboid-template> ./tools/test.ps1 
●●
2 successes / 0 failures / 0 errors / 0 pending : 0.0 seconds
All tests passed.
```

> 🐮 **Which tests are executed here, you wonder?** 🐮
> 
> This repository contains a single functionality: a logger and a test for it. So the two tests are testing your 
> brandnew logger mod.



#### 3. Rename the template

- execute `./tools/rename-template.ps1 -NewName "NewModName"`
- in _metadata.json_, check each line carefully and replace the values with what you need; you absolutely need to change:
  - `modId`
  - `authors` (so you can get the glory)
  - `workshop` > `id` (once you publish)
- optionally, edit _description.md_, because this is the long-form desciption of your mod
- optionally, edit _tools/templates/README.md - this file is your template for the Git repository's _README.md_ and so can contain information only relevant to developers

> 🐮 **Can I use `rename-template.ps1 -NewName "NewModName"` later?** 🐮
> 
> You technically can use this script to rename the mod again and again, but it might rename wrong
> positives after you started developing. Just commit before executing and you should be fine.


#### 4. Build

- finally, execute `./tools/build.ps1` to:
  - execute the tests
  - update the mod metadata
  - copy the mod data into the local _**Project Zomboid/mods/** folder

> 🎉 **Congratulations!!!** 🎉
> 
> Your first Project Zomboid mod is now installed.
> 
> Start the game, enable the mod and you're ready to begin developing.
> 
> **Happy modding!**




