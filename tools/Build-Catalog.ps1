<#
.SYNOPSIS
    Validates every scripts/<id>/script.json and regenerates catalog.json and the README table.

.DESCRIPTION
    catalog.json is what TrayTrigger will fetch. It is never hand-written: this script builds it
    from the manifests, adding a SHA-256 and size for every file, so a contributor cannot forge a
    hash and a reviewer only has to read the script and its manifest.

    Review is the security control. The hashes only prove that a downloaded file is the one the
    reviewer approved.

.PARAMETER Check
    Validate and build, but fail instead of writing if catalog.json or README.md would change.
    Used on pull requests so the generated files are only ever committed from main.
#>
[CmdletBinding()]
param(
    [switch] $Check
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $root 'scripts'
$utf8 = [System.Text.UTF8Encoding]::new($false)

$phases = 'prelaunch', 'postexit', 'both'
$allowedExt = '.ps1', '.bat', '.cmd'
$problems = New-Object System.Collections.Generic.List[string]
function Fail([string] $id, [string] $msg) { $problems.Add("scripts/$id`: $msg") }

$entries = @()
foreach ($dir in Get-ChildItem $scriptsDir -Directory | Sort-Object Name) {
    $id = $dir.Name
    if ($id -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { Fail $id 'folder name must be lower-case kebab-case'; continue }
    $manifestPath = Join-Path $dir.FullName 'script.json'
    if (-not (Test-Path $manifestPath)) { Fail $id 'script.json is missing'; continue }
    try { $m = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { Fail $id "script.json is not valid JSON: $($_.Exception.Message)"; continue }

    foreach ($req in 'name', 'description', 'author', 'phase', 'version', 'files') {
        if ($null -eq $m.$req -or ($m.$req -is [string] -and -not $m.$req.Trim())) { Fail $id "script.json is missing `"$req`"" }
    }
    if ($m.phase -and $m.phase -notin $phases) { Fail $id "phase must be one of: $($phases -join ', ')" }
    if ($m.PSObject.Properties['needsAdmin'] -and $m.needsAdmin -isnot [bool]) { Fail $id 'needsAdmin must be true or false' }
    if ($m.needsAdmin -eq $true -and -not $m.needsAdminReason) { Fail $id 'needsAdmin is true, so needsAdminReason must say why' }
    if ($m.version -and $m.version -notmatch '^\d+\.\d+(\.\d+)?$') { Fail $id 'version must look like 1.0 or 1.0.1' }
    if ($m.files -and $m.files.Count -eq 0) { Fail $id '"files" must list at least one file' }

    $files = @()
    foreach ($f in @($m.files)) {
        if ($f -match '[/\\]' -or $f -eq '..') { Fail $id "file `"$f`" must be a bare file name inside the folder"; continue }
        $path = Join-Path $dir.FullName $f
        if (-not (Test-Path $path)) { Fail $id "listed file `"$f`" does not exist"; continue }
        if ([System.IO.Path]::GetExtension($f).ToLowerInvariant() -notin $allowedExt) { Fail $id "`"$f`": only $($allowedExt -join ', ') are accepted" }
        $item = Get-Item $path
        $files += [ordered]@{
            path   = $f
            sha256 = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
            size   = $item.Length
        }
    }
    # Every script file in the folder must be listed, so nothing ships unreviewed.
    foreach ($extra in Get-ChildItem $dir.FullName -File | Where-Object { $_.Name -ne 'script.json' -and $_.Name -ne 'README.md' -and $_.Name -notin @($m.files) }) {
        Fail $id "file `"$($extra.Name)`" is in the folder but not listed in script.json"
    }

    $entries += [ordered]@{
        id               = $id
        name             = [string] $m.name
        description      = [string] $m.description
        author           = [string] $m.author
        version          = [string] $m.version
        phase            = [string] $m.phase
        needsAdmin       = [bool] ($m.needsAdmin -eq $true)
        needsAdminReason = if ($m.needsAdminReason) { [string] $m.needsAdminReason } else { $null }
        scriptArguments  = if ($m.scriptArguments) { [string] $m.scriptArguments } else { '' }
        dependencies     = if ($m.dependencies) { [string] $m.dependencies } else { '' }
        minAppVersion    = if ($m.minAppVersion) { [string] $m.minAppVersion } else { '1.4.0' }
        source           = "scripts/$id"
        files            = $files
    }
}

if ($problems.Count) {
    $problems | ForEach-Object { Write-Host "ERROR  $_" -ForegroundColor Red }
    throw "$($problems.Count) problem(s) found."
}

# catalog.json. generatedAt is omitted on purpose so the file only changes when a script does.
$catalog = [ordered]@{
    schemaVersion = 1
    repository    = 'stephenh678/TrayTrigger-Scripts'
    scripts       = $entries
}
$json = ($catalog | ConvertTo-Json -Depth 6) -replace "`r`n", "`n"
if (-not $json.EndsWith("`n")) { $json += "`n" }

# README table between the markers.
$readmePath = Join-Path $root 'README.md'
$readme = Get-Content $readmePath -Raw -Encoding UTF8
$rows = @('| Script | What it does | Phase | Admin | Script Arguments |', '|---|---|---|---|---|')
foreach ($e in $entries) {
    $admin = if ($e.needsAdmin) { 'yes' } else { 'no' }
    $args = if ($e.scriptArguments) { $e.scriptArguments } else { 'none' }
    $rows += "| [$($e.name)](scripts/$($e.id)) | $($e.description) | $($e.phase) | $admin | $args |"
}
$table = $rows -join "`n"
$pattern = '(?s)(<!-- CATALOG:START -->\r?\n)(?:.*?\r?\n)?(<!-- CATALOG:END -->)'
if ($readme -notmatch $pattern) { throw 'README.md is missing the <!-- CATALOG:START --> / <!-- CATALOG:END --> markers.' }
$newReadme = [regex]::Replace($readme, $pattern, { param($mm) $mm.Groups[1].Value + $table + "`n" + $mm.Groups[2].Value })

$catalogPath = Join-Path $root 'catalog.json'
$oldJson = if (Test-Path $catalogPath) { Get-Content $catalogPath -Raw -Encoding UTF8 } else { '' }
$changed = ($oldJson -ne $json) -or ($newReadme -ne $readme)

if ($Check) {
    if ($changed) { throw 'catalog.json or the README table is out of date. It is regenerated automatically when this PR is merged; do not edit it by hand.' }
    Write-Host "OK: $($entries.Count) script(s) validated; generated files are current."
} else {
    [System.IO.File]::WriteAllText($catalogPath, $json, $utf8)
    [System.IO.File]::WriteAllText($readmePath, $newReadme, $utf8)
    Write-Host "Wrote catalog.json ($($entries.Count) scripts) and the README table."
}
