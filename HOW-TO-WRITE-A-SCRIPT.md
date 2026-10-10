# How to write a TrayTrigger script

TrayTrigger runs a PowerShell script of yours just before a game starts and again after it exits. This page takes you from an empty file to a script you can share here: what TrayTrigger hands your script, how to structure it, how to tell the player what it did, how to test it, and how to submit it.

You don't need to be a PowerShell expert. Every script in this catalogue follows the same shape, so once you've read one you can read them all.

## 1. Start from the template

In TrayTrigger, open **Edit Game › Scripts** and click **New script...** next to the pre-launch box. Give it a name, and TrayTrigger writes a blank template into your scripts folder (`%AppData%\TrayTrigger\Scripts`), fills in the path and opens it in your editor. The template already reads every value TrayTrigger passes in and branches on the phase.

Prefer to start from a real script? Copy [`scripts/set-display-mode/Set-DisplayMode.ps1`](scripts/set-display-mode/Set-DisplayMode.ps1). Every script here is built the same way.

Tick **Use the same script for pre-launch and post-exit** so one file handles both phases.

## 2. What TrayTrigger passes to your script

TrayTrigger starts your script like this:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass [-WindowStyle Hidden] -File <your script> <1> <2> <3> <4> <5> <6...>
```

`-WindowStyle Hidden` is added when **Run scripts hidden** is ticked, and always for the **Test** button. The execution policy is bypassed for this one run, so a locked-down policy won't block your script.

The template's `param` block names the values:

```powershell
param(
    [string]$Phase,
    [string]$GameName,
    [string]$GameExe,
    [string]$GameId,
    [string]$Playtime,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)
```

| # | Name | What it holds |
|---|---|---|
| 1 | `$Phase` | `prelaunch` before the game, `postexit` after it. |
| 2 | `$GameName` | The game's name as shown in TrayTrigger. A leading `-` is removed, because PowerShell would read `-Foo` as a parameter name rather than a value. |
| 3 | `$GameExe` | The full path of the game's exe, unchanged. |
| 4 | `$GameId` | A stable ID for the game. Use it to name note files (see step 4). |
| 5 | `$Playtime` | Empty before the game, the minutes played after it. It's passed even when empty, so the values after it never shift. It's a string, so convert it: `$minutes = if ($Playtime) { [int]$Playtime } else { 0 }`. |
| 6+ | `$ScriptArgs` | Whatever the user typed in **Script Arguments**, split into words the way Windows splits a command line: spaces separate words, and double quotes keep a value together and are removed. `recommended "C:\My Tools\x.exe" force` arrives as three words. |

A default script (Settings › Launch & Performance) gets the game's own Script Arguments when the game has some, and the Default Script Arguments otherwise.

The same values are also in environment variables: `TRAYTRIGGER_PHASE`, `TRAYTRIGGER_GAME_NAME`, `TRAYTRIGGER_GAME_EXE`, `TRAYTRIGGER_GAME_ID` and, after the game, `TRAYTRIGGER_PLAYTIME_MINUTES`. `TRAYTRIGGER_GAME_NAME` is the exact name, a leading `-` included. **They are not set when the script runs as Administrator**, because Windows can't pass them through the administrator prompt. Read the arguments and your script works either way.

## 3. Use Script Arguments for anything that varies

Don't make people edit your file. Anything that differs from one PC or one game to the next (which app to close, where a program is installed, which profile to load) belongs in Script Arguments. Then one script serves a whole library, and an update to the script never wipes anyone's settings.

Decide what your script expects, write it in the header's `Script Arguments:` line, and handle an empty value sensibly. Doing nothing and saying so is usually right.

## 4. Carry state from before to after

The pre-launch run and the post-exit run are separate processes. To remember something between them, such as what you closed or what mode you changed from, write a small note file in TEMP named after the game ID, then read it and delete it after the game:

```powershell
$note = Join-Path $env:TEMP "TrayTrigger-YourScript-$GameId.txt"
```

Two cases to handle, because both happen in real life:

- **The pre-launch run can happen twice** (a cancelled launch, then a retry). Don't overwrite a note that's still there with "nothing changed".
- **The post-exit run can happen without a matching pre-launch run**, for example when TrayTrigger closed mid-game and runs it at the next start. No note means nothing to put back.

## 5. Tell the player what you did: `TT:` lines

Anything your script prints goes to TrayTrigger's log. A line that starts with `TT:` is different: it's for the player.

```powershell
Write-Output "TT: closed OneDrive and Discord"
```

From TrayTrigger 1.6.1, that line goes on the game's **Played** row in Activity & History, after the script's own "ran":

> Scripts: pre-launch Close-OneApp.ps1 ran · closed OneDrive and Discord.

It also shows in the launch popup while the game is still being prepared.

- Write a short fragment in plain words that reads well after "ran · ". One or two lines per phase is plenty; up to five per run are kept, each cut at 200 characters.
- **When your script fails, say why before you exit non-zero.** The last `TT:` line becomes the explanation on the problem row, and in the popup if the launch was cancelled. `TT: Afterburner isn't installed at the path in Script Arguments` beats "exit code 1".
- Only a script that runs hidden and not as Administrator is heard, because those are the runs whose output TrayTrigger captures.

## 6. Exit codes

Exit `0` for success. A non-zero exit code is logged and recorded as a problem. It only stops the game from starting when the user ticked **Cancel the launch if the pre-launch script fails**. Don't exit non-zero just because there was nothing to do.

## 7. A complete example

This script closes one app you name before the game and reopens it after. Close Background Apps in this catalogue is the full version; this is the shape at its smallest.

```powershell
<#
  Name:             Close One App
  Description:      Closes the app named in Script Arguments before a game and reopens it after.
  Author:           your-github-name
  Version:          1.0
  Phase:            both
  Needs admin:      no
  Dependencies:     none
  Script Arguments: the app's process name, such as Spotify
#>
param(
    [string]$Phase,
    [string]$GameName,
    [string]$GameExe,
    [string]$GameId,
    [string]$Playtime,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

# Which app: the first word of Script Arguments, with or without ".exe".
$name = "$($ScriptArgs | Select-Object -First 1)" -replace '\.exe$', ''
if (-not $name) {
    Write-Output 'TT: no app named in Script Arguments, nothing to do'
    exit 0
}

# Carries the app's path from the pre-launch run to the post-exit run.
$note = Join-Path $env:TEMP "TrayTrigger-CloseOneApp-$GameId.txt"

switch ($Phase) {
    'prelaunch' {
        # Only a copy we can see the path of: one running as Administrator can't be reopened.
        $running = Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.Path } | Select-Object -First 1
        if (-not $running) {
            Write-Output "TT: $name wasn't running"
            exit 0
        }
        Set-Content -LiteralPath $note -Value $running.Path

        # taskkill without /F asks the app to close, the way signing out does.
        & (Join-Path $env:WINDIR 'System32\taskkill.exe') /IM "$name.exe" 2>&1 | Out-Null
        Wait-Process -Name $name -Timeout 5 -ErrorAction SilentlyContinue

        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            # It's still running, so there is nothing to reopen later.
            Remove-Item -LiteralPath $note -ErrorAction SilentlyContinue
            Write-Output "TT: $name didn't close when asked, so it was left running"
            exit 0
        }
        Write-Output "TT: closed $name"
    }
    'postexit' {
        # No note: nothing was closed, or the pre-launch run never happened.
        if (-not (Test-Path -LiteralPath $note)) { exit 0 }
        $path = Get-Content -LiteralPath $note -TotalCount 1
        Remove-Item -LiteralPath $note -Force

        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            Write-Output "TT: $name was already running again"
            exit 0
        }
        Start-Process -FilePath $path
        Write-Output "TT: reopened $name"
    }
    default {
        Write-Output "Unknown phase '$Phase'"
        exit 1
    }
}
exit 0
```

## 8. Test it

Press **Test** next to each script box in Edit Game. TrayTrigger runs the script right away, the way it will at launch, and shows the exit code and everything it printed, `TT:` lines included.

A test differs from a real launch in a few ways, and the result dialog says when your settings would make a difference:

- It uses what's typed in the dialog right now: the Name box (or `Unnamed Game` if it's empty), the executable box and Script Arguments, with the saved game's ID.
- A post-exit test passes a playtime of `0`.
- It always runs hidden and never as Administrator, and it's stopped after 30 seconds. A real run is never stopped.

Test both phases, in order. Then test the awkward cases from step 4: run the pre-launch test twice, and run the post-exit test on its own.

## 9. Things that trip people up

- **Windows PowerShell 5.1, not PowerShell 7.** TrayTrigger runs `powershell.exe`, which is on every Windows PC. Don't rely on `pwsh`-only features such as `??`, ternaries or `ForEach-Object -Parallel`.
- **Keep the file ASCII.** Windows PowerShell reads a file without a byte-order mark in the PC's ANSI code page, so a curly quote or an em dash pasted from a web page arrives garbled. Use straight quotes and plain hyphens.
- **Don't wait forever.** If the user ticks **Wait for the pre-launch script**, the game waits for you (10 seconds by default). Do your work and exit, and use `-Timeout` on anything that waits.
- **Avoid needing Administrator.** It means a Windows prompt on every launch, no environment variables, and no `TT:` lines, because the output isn't captured. If you truly need it, say exactly why in the manifest.
- **Close only what's yours to close:** what the user named in Script Arguments, or what your script started.

## 10. Share it

When it works for you, share it here:

1. Fork this repository and add a folder under `scripts/` named after your script (`close-one-app`), with your `.ps1` and a `script.json` beside it.
2. Fill in `script.json` as [CONTRIBUTING.md](CONTRIBUTING.md) describes, and give the script the same header block as the others: Name, Description, Author, Version, Phase, Needs admin, Dependencies, Script Arguments, then WHY, SET IT UP, HOW IT WORKS and GOOD TO KNOW.
3. Run `tools/Build-Catalog.ps1 -Check` if you have PowerShell handy. The pull request runs it too.
4. Open a pull request and tick the review checklist in CONTRIBUTING.md, saying what you saw when you tested both phases.

Want feedback first? Post it in [TrayTrigger's Show and tell](https://github.com/stephenh678/TrayTrigger/discussions/7).
