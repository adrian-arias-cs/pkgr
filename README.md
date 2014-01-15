pkgr
==========

A tool to automate building native packages for Debian and RedHat based distros.

# Overview
There are two processes for building packages. Building "new" packages refers to packaging a project hosted in git for the first time. This creates the necessary files using using values provided on the command line. For debian packages this usually involves creating the following files:

* **debian/control** - the core information about the package (name, dependencies, package maintainer, description, etc.)
* **debian/install** - only required if no makefile or buildsystem is shipped with the project
* **debian/rules** - only if it is necessary to override different phases of the debuild process (for example overriding the build step to invoke 'mvn package')
* **debian/changelog** - a rolling log of the changes between version
* **debian/copyright** - the license of the various components of the project

For rpm packages the same bits of information are required. The difference being, they are added to a single file (the spec file).

The following list outlines the required tid-bits for generating the inital package.

* project name
* dependencies
* version being packaged
* description
* files to be packaged (if not using a buildsystem that will install the files)
* package maintainer

Other, optional files include:
* man pages
* docs
* example configuration files
* and more

Alternatively, packages can be created for the "next-release". In this case the necessary information can be extracted from the previously packaged version's files.

In either case the changelog entries come from git log.

Usage
----------
	pkgr <project_name> <version_string>

*<project_name>* corresponds with the name of the project in git and the directory in which the project is in.
*<version_string* must match one of the following formats:
    0.0.1
    0.0.1-rc1

Options
----------
	-h|--help                                      Show this message
	-t[package type]|--type[=package type]     Specify the package type, either 'rpm' or 'deb'. The default is deb.
	-n|--new                                       Build a first release package
	-d|--description[description]                       Description of the project. If no description is provided it will be prompted for.

Parameters:
	project_name                                   The name of the project (as it is in the VCS)
	version_string                                 The version to package (must be a tagged release)

Examples
----------
Package the next release for Debian or Ubuntu:

	pkgr pentaho-reporting 0.0.2-rc1

Package a project for rpm for the first time:

	pkgr -n -tdeb --description pentaho-reporting 0.0.1-rc1 --install-file <install_file> --rules-file <rules_file> --packager-name <packager_name> --packager-email <packager_email> --dependencies 'dep1, dep2, ...' --build-deps 'dep1, dep2, ...'

