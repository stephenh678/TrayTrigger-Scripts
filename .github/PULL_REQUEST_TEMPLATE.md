## Script

<!-- Name, and one sentence on what it does for the player. -->

## Review checklist

- [ ] Uses only the documented arguments, Script Arguments, or `TRAYTRIGGER_*` variables
- [ ] No downloads, no network calls
- [ ] No `Invoke-Expression` / `iex`, no encoded commands, no `Install-Module`, no `Set-ExecutionPolicy`
- [ ] Nothing destructive: closes only what the user named or the script started; leaves no state behind after post-exit except what the description says
- [ ] `needsAdmin` is false, or `needsAdminReason` explains exactly why
- [ ] Every action is commented
- [ ] Safe if pre-launch runs twice, or post-exit runs without a pre-launch
- [ ] `catalog.json` and the README table are untouched (they're regenerated on merge)

## How I tested it

<!-- Test Run in TrayTrigger, both phases. What did it print? Which game, which Script Arguments? -->
