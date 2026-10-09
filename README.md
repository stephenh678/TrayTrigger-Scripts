<p align="center">
  <img src="https://raw.githubusercontent.com/stephenh678/TrayTrigger/main/Assets/app_icon.png" width="72" alt="TrayTrigger icon">
</p>

<h1 align="center">TrayTrigger Scripts</h1>

<p align="center">
  Community pre-launch and post-exit scripts for <a href="https://github.com/stephenh678/TrayTrigger">TrayTrigger</a>.<br>
  Reviewed before they're listed. Hashed so what you download is what was reviewed.
</p>

---

TrayTrigger runs a script of your choosing just before a game starts and again after it exits, with the game's name, path and minutes played handed in. If TrayTrigger doesn't do something you want before or after a game, a script here probably does, or shows you how: switch your display's refresh rate for one game and put it back, change an Afterburner profile, pause your wallpaper, close the apps that fight your game for bandwidth, start the tools a sim needs, record with OBS, back up your saves, log your playtime.

Every script here says what it did in its own words: a line it prints starting with `TT:` lands on the game's Played row in TrayTrigger's Activity & History ("Scripts: pre-launch Example-CloseBackgroundApps.ps1 ran · closed OneDrive and Discord") and in the launch popup while the game waits. From TrayTrigger 1.6.1; older versions treat the line as ordinary output.

> **Read before you run.** A script runs as you, with your privileges. Every script here was read by a maintainer before it was merged, and `catalog.json` carries a SHA-256 for every file so a download can be checked against what was reviewed. That's a review, not a guarantee. Open the script, read the header, and decide for yourself.

## Scripts

<!-- CATALOG:START -->
| Script | What it does | Phase | Admin | Script Arguments |
|---|---|---|---|---|
| [Set Afterburner Profile](scripts/afterburner-profile) | Switches MSI Afterburner to one of its five profiles for a game, and to another one after it. | both | yes | the profile number for the game (1 to 5), optionally the number to switch to after it ("3 1"); a path ending in MSIAfterburner.exe overrides where it's looked for |
| [Close Background Apps](scripts/close-background-apps) | Closes background apps, such as cloud sync, before a game and reopens them after. Ships with TrayTrigger. | both | no | "recommended" for the recommended list (OneDrive, Dropbox, Google Drive), and/or process names to close, separated by spaces, and "force" to end any that don't close when asked; empty does nothing |
| [Start Companion Apps](scripts/companion-apps) | Starts the tools a game needs when it launches and closes them when it exits. Ships with TrayTrigger. | both | no | full paths of the programs to start, each in double quotes, and "force" to end any that don't close when asked |
| [Log Playtime](scripts/log-playtime) | Appends one line per session to a CSV file: when you played, which game, and for how long. | postexit | no | optionally the full path of the CSV file in double quotes; Documents\TrayTrigger Playtime.csv by default |
| [OBS Replay Buffer](scripts/obs-replay-buffer) | Runs OBS in the tray with the replay buffer on while you play, or recording, then closes it so a recording is saved. | both | no | "record" to record instead of running the replay buffer, and optionally an OBS profile name in double quotes |
| [Save Backup](scripts/save-backup) | Zips a game's save folder before and after you play and keeps the newest ten. | both | no | the save folder in double quotes, then optionally a backup folder |
| [Set Display Mode](scripts/set-display-mode) | Switches a display's refresh rate and/or resolution for one game and puts the previous mode back when the game exits. | both | no | a refresh rate ("144"), a resolution ("1920x1080"), or both; "display:2" for a display other than the primary |
| [Wallpaper Engine Pause](scripts/wallpaper-engine-pause) | Pauses and mutes Wallpaper Engine while you play, then resumes it. | both | no | none |
<!-- CATALOG:END -->

Every script opens with a comment block: why you'd want it, how to set it up, how it works, and a **Change these** section with the settings you might edit. Close Background Apps and Start Companion Apps also ship inside TrayTrigger; the copies here are the same files.

## Installing a script

1. Open your scripts folder: in TrayTrigger, Settings › Launch & Performance › *Open scripts folder* (it's `%AppData%\TrayTrigger\Scripts`). *Get more scripts*, next to it, opens this page.
2. Download the script's `.ps1` from its folder here into your scripts folder. Keep the file name.
3. In TrayTrigger, Edit Game › *Scripts* › Browse to the file. For a script whose phase is **both**, choose it as the pre-launch script and tick *Use the same script for pre-launch and post-exit*. For every game, set it as a default script in Settings › Launch & Performance instead.
4. Type anything the script expects into **Script Arguments** (the table above and the script's header say what).
5. Press **Test** next to each box. You see what it does and what it prints without launching the game.

Once it's in your folder the script is yours: TrayTrigger never changes a file it didn't put there. A newer version here is never installed over it by itself.

## Sharing a script

Post it in [Show and tell](https://github.com/stephenh678/TrayTrigger/discussions/7) first if you want feedback, or open a pull request here directly. [CONTRIBUTING.md](CONTRIBUTING.md) has the folder layout, the `script.json` fields, and the review checklist. The short version:

- PowerShell only, one folder per script under `scripts/`, with a `script.json` next to it.
- Only the documented arguments and Script Arguments. No downloads, no network calls, no `Invoke-Expression`, no module installs.
- Nothing destructive. Close only processes the user named or the script itself started, and put back whatever you change.
- Says what it did with `TT:` lines.
- `needsAdmin` off, or justified in the manifest.
- Tested with Test Run in both phases.

## How the catalog works

- `scripts/<id>/script.json` is the manifest a contributor writes: name, description, author, phase, whether it needs admin (and why), what it expects in Script Arguments, dependencies, version, and the list of files.
- `catalog.json` is generated by [`tools/Build-Catalog.ps1`](tools/Build-Catalog.ps1) on every merge to `main`: every manifest plus a SHA-256 and size per file. Pull requests are validated against the same script; the generated file is never edited by hand.
- The table above is regenerated at the same time.

## Script contract

Arguments, in order: phase (`prelaunch` or `postexit`), game name, game exe path, game ID, playtime in minutes (empty on pre-launch). Script Arguments follow from `$args[5]`; every script here reads them all through the same `param` block. Environment variables `TRAYTRIGGER_PHASE`, `TRAYTRIGGER_GAME_NAME`, `TRAYTRIGGER_GAME_ID`, `TRAYTRIGGER_GAME_EXE`, and after exit `TRAYTRIGGER_PLAYTIME_MINUTES` (not set when running as Administrator). A line printed as `TT: ...` is shown to the player on the game's Played row and in the launch popup; up to five per run, the last one explaining a failure. Full details on the wiki: [Pre-Launch and Post-Exit Scripts](https://github.com/stephenh678/TrayTrigger/wiki/Pre-Launch-and-Post-Exit-Scripts) and [Writing your own script](https://github.com/stephenh678/TrayTrigger/wiki/Writing-your-own-script).

## License

MIT, same as TrayTrigger. By contributing a script you agree to license it the same way.
