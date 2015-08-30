# NBICreator

![NBICreator](https://raw.githubusercontent.com/NBICreator/NBICreator/master/GitHub%20Resources/NBICreatorIconGitHubBanner_text.png)

NBICreator is a NetInstall image creation tool written in Objective-C.

It currently supports the following NetInstall images:
* [NetInstall](https://github.com/NBICreator/NBICreator/wiki/NetInstall)
* [DeployStudio](https://github.com/NBICreator/NBICreator/wiki/DeployStudio)
* [Imagr](https://github.com/NBICreator/NBICreator/wiki/Imagr)

The design and idea of the application is to be able to create different types of NetInstall images in one single application, and to save the configuration in a template to be reused when the NetInstall image need to be updated for newer versions of the OS.

# Download

You can download the latest version from the [Releases](https://github.com/NBICreator/NBICreator/releases) page.

# Important

This project is currently considered to be in beta, so major changes will occur between builds that may require manual action or reinstall.

The code will also see major changes as some parts are being restructured.

Passwords are currently saved in clear text in the template file, so if you need to keep the passwords secure you have to enter them each time you select a template, and remember not to save when prompted! Later they will most likely be stored in an application keychain, but that code isn't implemented yet.

# System Requirements

NBICreator requires Mac OS X 10.10 or newer.

# Getting Started

To get started, read [Getting started](https://github.com/NBICreator/NBICreator/wiki/Getting-started)

Documentation is available in the [Wiki](https://github.com/NBICreator/NBICreator/wiki)

# License
    Copyright 2015 Erik Berglund. All rights reserved.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
      http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
