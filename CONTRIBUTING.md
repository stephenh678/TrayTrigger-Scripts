# Contributing a script

Thanks for sharing. Every script in this catalog is read by a maintainer before it's merged, because it will run on other people's PCs with their privileges. The checklist below is what the review looks for; going through it first makes the review fast.

## Folder layout

```
scripts/
  your-script-id/
    script.json          the manifest (required)
    YourScript.ps1       the script (one or more files, .ps1 / .bat / .cmd)
```

- The folder name is the script's id: lower-case, hyphens, no spaces (`save-backup`, `obs-replay-buffer`).
- Every script file in the folder must be listed in `script.json`. Nothing ships unlisted.
- No binaries, no archives, no files that aren't scripts.

## script.json

```json
{
  "name": "Quiet Mode",
  "description": "Closes the background apps you name before a game and reopens them after.",
  "author": "your-github-name",
  "version": "1.0",
  "phase": "both",
  "needsAdmin": false,
  "scriptArguments": "process names to close, separated by spaces",
  "dependencies": "none",
  "minAppVersion": "1.4.0",
  "files": ["Example-QuietMode.ps1"]
}
```

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Shown in the catalog and, later, in the app. |
| `description` | yes | One sentence. What it does for the player. |
| `author` | yes | Your GitHub user name, or a name you want credited. |
| `version` | yes | `1.0`, `1.1`, `2.0.1`. Bump it when you change the script. |
| `phase` | yes | `prelaunch`, `postexit`, or `both`. A `both` script branches on its first argument. |
| `needsAdmin` | no | Defaults to `false`. If `true`, `needsAdminReason` is required and the review will ask whether it's really needed. |
| `scriptArguments` | no | What the user should type into Script Arguments, or leave out if the script takes none. |
| `dependencies` | no | Free text: "OBS Studio 30 or newer", "AudioDeviceCmdlets module". Leave out for none. |
| `minAppVersion` | no | Defaults to `1.4.0`, the first TrayTrigger with scripts. |
| `files` | yes | Bare file names in the folder. |

Do **not** edit `catalog.json` or the README table. Both are regenerated when your PR is merged, and the PR check fails if they're edited by hand.

## The script itself

Open it with a comment block in the style of the bundled examples: **Name / Description / Author / Version / Phase / Needs admin / Dependencies / Script Arguments**, then **WHY**, **SET IT UP**, **HOW IT WORKS**, **GOOD TO KNOW**, and a `# ---- Change these ----` section for anything a user might edit. Copy [`scripts/quiet-mode/Example-QuietMode.ps1`](scripts/quiet-mode/Example-QuietMode.ps1) as a starting point.

## Review checklist

The maintainer checks every one of these. Tick them in the PR.

- [ ] Uses only the documented positional arguments (`%1`–`%5` / `$args[0..4]`) and Script Arguments (`%6`+ / `$args[5..]`), or the `TRAYTRIGGER_*` environment variables.
- [ ] No downloads and no network calls.
- [ ] No `Invoke-Expression`, no `iex`, no `Start-Process powershell -EncodedCommand`, no module installs (`Install-Module`), no `Set-ExecutionPolicy`.
- [ ] Nothing destructive: closes only processes the user named in Script Arguments or that the script itself started. No deleting files it didn't create, no registry writes outside the script's stated purpose, no changes that survive the post-exit phase.
- [ ] `needsAdmin` is `false`, or `needsAdminReason` says exactly which action needs elevation and why it can't be avoided.
- [ ] Every action has a comment saying what it does and why.
- [ ] Handles the pre-launch phase being run twice (a launch that was cancelled, then retried) and the post-exit phase running without a matching pre-launch (TrayTrigger closed mid-game and ran it on next start).
- [ ] Tested with **Test Run** in TrayTrigger for both phases, and the PR says what you saw.
- [ ] Leaves no state behind after post-exit except what the description says it keeps (a backup file, for example).

## Updating a script you contributed

Open a PR that bumps `version` in `script.json` and explains the change. Users are never auto-updated; the app will show "newer version in catalog" and let them re-install explicitly.

## Reporting a problem with a script

Open an issue here naming the script. If it's a security problem (a script does something its description doesn't say), use [TrayTrigger's private reporting](https://github.com/stephenh678/TrayTrigger/security/advisories/new) instead of a public issue.

## License

By contributing you agree your script is licensed under the MIT License, the same as this repository and TrayTrigger.
