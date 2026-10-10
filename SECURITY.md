# Security Policy

Scripts in this catalog run on other people's PCs, as them. That is why every one is read by a maintainer before it's listed, and why `catalog.json` carries a SHA-256 for each file.

## Reporting a problem with a script

If a script does something its description doesn't say (deletes files it shouldn't, makes a network call, installs something, hides what it does), please report it **privately** with [GitHub Security Advisories](https://github.com/stephenh678/TrayTrigger-Scripts/security/advisories/new) rather than a public issue. Include the script's folder name and version.

A script that is merely buggy, or doesn't work with your setup, is an ordinary [issue](https://github.com/stephenh678/TrayTrigger-Scripts/issues/new/choose).

## What happens next

You can expect a first reply within a few days. This is a solo-maintained project. A script confirmed to be unsafe is removed from `catalog.json` and the repository straight away, and the reason is noted in the commit.

## Supported versions

Only what's on `main` is current. A script you downloaded earlier is yours and is never changed or removed from your PC by this repository.

## Security issues in TrayTrigger itself

Report those at [TrayTrigger's security policy](https://github.com/stephenh678/TrayTrigger/security/policy).
