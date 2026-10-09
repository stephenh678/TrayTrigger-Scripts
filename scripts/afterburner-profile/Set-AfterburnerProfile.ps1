<#
  Name:             Set Afterburner Profile
  Description:      Switches MSI Afterburner to one of its five profiles for a game,
                    and to another one after it.
  Author:           TrayTrigger
  Version:          1.0
  Phase:            both
  Needs admin:      yes - Afterburner itself runs as Administrator, so tick
                    "Run scripts as Administrator" in Edit Game
  Dependencies:     MSI Afterburner
  Script Arguments: the profile number for the game (1 to 5), and optionally the
                    number to switch to after it, for example "3 1". A path ending
                    in MSIAfterburner.exe overrides where the script looks for it.

  Once this file is in your scripts folder it is yours: TrayTrigger never changes
  it. Settings that vary by PC belong in Edit Game > Script Arguments.

  WHY
    One game is happy at stock clocks and quiet fans; another wants the
    overclock and the aggressive fan curve. Afterburner keeps up to five
    profiles for exactly that, and can be told to switch with a command-line
    switch. This script sends it for the games you choose it for, and sends
    the "after" profile when the game exits.

  SET IT UP
    1. In Afterburner, set up the profiles and save them to slots 1 to 5.
    2. In Edit Game, choose this file as the pre-launch script and tick "Use
       the same script for pre-launch and post-exit".
    3. In Script Arguments, type the profile for the game, then the one to go
       back to:
         3 1        profile 3 while the game runs, profile 1 after it
         3          profile 3 while the game runs, left there after
    4. Tick "Run scripts as Administrator". Afterburner runs as Administrator
       and only takes orders from a program that does too. Windows asks for
       permission at every launch; say no and the profile is left as it is.
    5. If Afterburner isn't in its usual folder, add the full path to
       MSIAfterburner.exe in Script Arguments, in double quotes.
    6. Press Test next to each box. The Test run isn't elevated, so it checks
       the arguments and the path and says what the real run will do.

  HOW IT WORKS
    prelaunch  Runs MSIAfterburner.exe -ProfileN. A running Afterburner
               switches at once; one that isn't running starts, switches, and
               stays open in the tray.
    postexit   The same with the second number, if there is one.

  GOOD TO KNOW
    Afterburner applies a profile's clocks and fan curve as it does when you
    click the slot button. A profile that isn't saved does nothing.
    Afterburner doesn't say which profile was active before, so the "after"
    profile is the one you name, not "whatever it was".

  MAKE IT YOURS
    The usual Afterburner folder is set below. Change it there, or pass the
    path in Script Arguments.
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

# ---- Change these ------------------------------------------------------------

$AfterburnerPath = Join-Path ${env:ProgramFiles(x86)} 'MSI Afterburner\MSIAfterburner.exe'

# ------------------------------------------------------------------------------

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# Read the arguments: up to two profile numbers, and an optional path.
$profiles = @()
foreach ($arg in $ScriptArgs) {
    if ($arg -match '^[1-5]$') { $profiles += [int]$arg }
    elseif ($arg -match '\.exe$') { $AfterburnerPath = $arg }
    else { Write-Output "Ignoring '$arg': not a profile number from 1 to 5, or a path to MSIAfterburner.exe." }
}
if ($profiles.Count -eq 0) {
    Write-Output 'TT: no profile named. Put a number from 1 to 5 in Edit Game > Script Arguments, and a second one to switch to after the game.'
    exit 1
}
if (-not (Test-Path -LiteralPath $AfterburnerPath -PathType Leaf)) {
    Write-Output "TT: MSI Afterburner isn't at $AfterburnerPath; put its full path in Script Arguments"
    exit 1
}

$wanted = switch ($Phase) {
    'prelaunch' { $profiles[0] }
    'postexit'  { if ($profiles.Count -ge 2) { $profiles[1] } else { 0 } }
    default     { Write-Output "Unknown phase '$Phase'."; exit 1 }
}
if ($wanted -eq 0) {
    Write-Output "TT: Afterburner left on profile $($profiles[0])"
    exit 0
}

# A Test run isn't elevated, and Afterburner would only answer with a permission prompt.
if (-not $isAdmin) {
    Write-Output "Not running as Administrator, so Afterburner wasn't told anything. The real run, with 'Run scripts as Administrator' ticked, switches to profile $wanted."
    Write-Output "TT: would switch Afterburner to profile $wanted (needs Run scripts as Administrator)"
    exit 0
}

try {
    Start-Process -FilePath $AfterburnerPath -ArgumentList "-Profile$wanted" -ErrorAction Stop
    if ($Phase -eq 'prelaunch') { Write-Output "TT: Afterburner on profile $wanted" }
    else { Write-Output "TT: Afterburner back on profile $wanted" }
}
catch {
    Write-Output "TT: Afterburner couldn't be started to switch profiles: $($_.Exception.Message)"
    exit 1
}

exit 0
