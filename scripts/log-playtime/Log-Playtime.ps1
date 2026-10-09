<#
  Name:             Log Playtime
  Description:      Appends one line per session to a CSV file: when you played,
                    which game, and for how long.
  Author:           TrayTrigger
  Version:          1.0
  Phase:            postexit (harmless as a pre-launch script: it does nothing then)
  Needs admin:      no
  Dependencies:     none
  Script Arguments: optionally the full path of the CSV file in double quotes.
                    Documents\TrayTrigger Playtime.csv by default.

  Once this file is in your scripts folder it is yours: TrayTrigger never changes
  it. Settings that vary by PC belong in Edit Game > Script Arguments.

  WHY
    TrayTrigger keeps each game's total and shows every session in Activity &
    History, for 90 days or a year. A CSV you own keeps every session for
    good, in a file Excel, a spreadsheet or a script of yours can read: hours
    per week, which games got the evenings, how long a playthrough took.

  SET IT UP
    1. In Settings > Launch & Performance, choose this file as the default
       post-exit script and tick "Run the default scripts", so every game is
       logged. Or choose it for one game in Edit Game.
    2. Leave Script Arguments empty for Documents\TrayTrigger Playtime.csv,
       or put another path in double quotes.
    3. Press Test next to the post-exit box: a line with 0 minutes is added,
       which you can delete.

  HOW IT WORKS
    postexit   Appends a line: date, start time, end time, game, minutes,
               and the game's exe. The header is written when the file is
               new. The start time is worked out from the minutes played.
    prelaunch  Nothing. Choosing it as both scripts is fine.

  GOOD TO KNOW
    The minutes come from TrayTrigger, for every launch type it can follow,
    Steam included. A game launched from a bare link isn't timed, so no
    line is written for it.
    Open the file in Excel with the comma as the separator. Dates are
    year-month-day, so they sort.

  MAKE IT YOURS
    Change $Separator below to a semicolon if your Excel expects one.
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

$LogPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'TrayTrigger Playtime.csv'
$Separator = ','

# ------------------------------------------------------------------------------

foreach ($arg in $ScriptArgs) {
    if ($arg) { $LogPath = [Environment]::ExpandEnvironmentVariables($arg) }
}

if ($Phase -ne 'postexit') {
    if ($Phase -ne 'prelaunch') { Write-Output "Unknown phase '$Phase'."; exit 1 }
    Write-Output 'Nothing to log before the game.'
    exit 0
}

$minutes = if ($Playtime -match '^\d+$') { [int]$Playtime } else { 0 }
$end = Get-Date
$start = $end.AddMinutes(-$minutes)

# A value with the separator, a quote or a line break in it goes in quotes, as CSV wants.
function Quote([string]$value) {
    if ($value -match "[$([regex]::Escape($Separator))`"`r`n]") { return '"' + ($value -replace '"', '""') + '"' }
    return $value
}

try {
    $folder = Split-Path -Parent $LogPath
    if ($folder -and -not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $LogPath)) {
        Set-Content -LiteralPath $LogPath -Value (@('Date', 'Start', 'End', 'Game', 'Minutes', 'Exe') -join $Separator) -Encoding UTF8
    }
    $line = @(
        $start.ToString('yyyy-MM-dd'),
        $start.ToString('HH:mm'),
        $end.ToString('HH:mm'),
        (Quote $GameName),
        $minutes,
        (Quote $GameExe)
    ) -join $Separator
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}
catch {
    Write-Output "TT: the playtime couldn't be written to ${LogPath}: $($_.Exception.Message)"
    exit 1
}

Write-Output "Logged: $line"
Write-Output "TT: $minutes minute(s) logged to $(Split-Path -Leaf $LogPath)"
exit 0
