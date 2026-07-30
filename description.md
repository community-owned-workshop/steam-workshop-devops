[![](https://raw.githubusercontent.com/community-owned-workshop/wiki/refs/heads/main/assets/banner-title-seals.png)](https://community-owned-workshop.github.io/wiki/creating-a-mod/)

This repository can be used as a template for creating new mods for [Project Zomboid](https://store.steampowered.com/agecheck/app/108600/).

Copy this repository contents and execute `./tools/setup.ps1` to install Lua and Busted for executing tests. Don't 
worry, this will not change your system, but only copy the data into this project.

Afterwards, `./tools/test.ps1` will execute the tests (there are two in this project).

`./tools/build.ps1` will execute the tests and if that was successful, copy the mod Data into the **Project Zomboid** 
repository.

`./tools/generate-metadata.ps1` will generate the meta data (_mod.info_, _README.md_, _workshop.txt_) from a
common source. This source is

- _metadata.json_ - for general info like ID and version
- _description.md_ - for a long description of your mod
- _tools/templates/README.md_ - a template for the README file of this repository; add stuff that is only relevant for the code here

You can use `./tools/Rename-Template.ps1 -NewName "NewModName"` to rename all folders, files and all text files at once.
Note that you technically can use this script to rename the mod again and again, but it might rename wrong
positives after you started developing.