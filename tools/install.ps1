<#
.SYNOPSIS
    Installs the MD Mayhem mutation-core plugin into an EDOPro / MDPro3 client.

.DESCRIPTION
    Copies the Lua modules into <GamePath>\expansions\script\mdmayhem\, drops the
    bootstrap at <GamePath>\init.lua (EDOPro loads that file into every duel it
    creates) and installs the generated banlist into <GamePath>\lflists\.

    Cores are chosen per match by typing a code into the Host window's Starting LP
    box, with the list dropped at <GamePath>\Mayhem-codes.txt. Nothing in the
    client itself is patched: no game mode, card script or interface string is
    altered.

    mayhem_config.lua holds settings that apply to every match, so an existing copy
    is never overwritten unless -Force is passed. An existing init.lua that belongs
    to something else is backed up to init.lua.bak first.

    Only the duel host needs the plugin: EDOPro runs the duel core on the hosting
    client, so the host's rules are the rules both players play under.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\install.ps1
    powershell -ExecutionPolicy Bypass -File tools\install.ps1 -GamePath "D:\EDOPro" -Force

    With no -GamePath the script scans the fixed drives for EDOPro.exe and asks
    which install to use, then remembers the answer in <repo>\.game-path.
#>
[CmdletBinding()]
param(
    [string]$GamePath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "resolve-game-path.ps1")
$GamePath = Resolve-GamePath -GamePath $GamePath -Repo $repo

$pluginDir = Join-Path $GamePath "expansions\script\mdmayhem"
$configName = "mayhem_config.lua"

New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $GamePath "lflists") | Out-Null

# --- Lua modules -----------------------------------------------------------
# Duel.LoadScript rejects names containing a path separator, so every module
# has to sit flat in one folder that EDOPro already scans. install\generated
# holds the core catalogue built by build-catalogue.py.
$generatedDir = Join-Path $repo "install\generated"
if (-not (Test-Path (Join-Path $generatedDir "mayhem_catalogue.lua"))) {
    throw "install\generated is missing. Run: python tools\build-catalogue.py"
}

# Earlier versions hijacked EDOPro's 13 extra-rule checkboxes. That is gone: the
# stock modes must keep working, so anything that overrode them is removed here.
$obsolete = @(Get-ChildItem $pluginDir -Filter "c*.lua" -ErrorAction SilentlyContinue) +
            @(Get-ChildItem $pluginDir -Filter "mayhem_slots.lua" -ErrorAction SilentlyContinue) +
            @(Get-ChildItem $pluginDir -Filter "mayhem_hooks.lua" -ErrorAction SilentlyContinue)
foreach ($stale in $obsolete) {
    Remove-Item $stale.FullName -Force
    Write-Host "remove $($stale.Name) (obsolete checkbox override)"
}

# src/ is split for readability but the install has to be flat, so src\cores\<id>.lua
# lands as mayhem_core_<id>.lua - the name MAYHEM.ApplyCore derives from the core id.
$sources = @()
foreach ($file in Get-ChildItem (Join-Path $repo "src\runtime") -Filter *.lua) {
    $sources += [pscustomobject]@{ Source = $file.FullName; Name = $file.Name }
}
foreach ($file in Get-ChildItem (Join-Path $repo "src\cores") -Filter *.lua) {
    $sources += [pscustomobject]@{ Source = $file.FullName; Name = "mayhem_core_$($file.Name)" }
}
foreach ($file in Get-ChildItem $generatedDir -Filter *.lua) {
    $sources += [pscustomobject]@{ Source = $file.FullName; Name = $file.Name }
}

foreach ($file in $sources) {
    $target = Join-Path $pluginDir $file.Name
    if ($file.Name -eq $configName -and (Test-Path $target) -and (-not $Force)) {
        Write-Host "keep   $($file.Name) (existing config, use -Force to reset)"
        continue
    }
    Copy-Item $file.Source $target -Force
    Write-Host "copy   $($file.Name)"
}

# --- Interface strings -----------------------------------------------------
# An earlier version retitled the Host window here. EDOPro's own interface is
# left alone now, so any block we wrote before is taken back out.
$expansionStrings = Join-Path $GamePath "expansions\strings.conf"
if (Test-Path $expansionStrings) {
    $kept = @()
    $inBlock = $false
    $found = $false
    foreach ($line in [System.IO.File]::ReadAllLines($expansionStrings, [System.Text.Encoding]::UTF8)) {
        if ($line -eq "# >>> MD Mayhem") { $inBlock = $true; $found = $true; continue }
        if ($line -eq "# <<< MD Mayhem") { $inBlock = $false; continue }
        if (-not $inBlock) { $kept += $line }
    }
    if ($found) {
        if (($kept | Where-Object { $_.Trim() -ne "" }).Count -eq 0) {
            Remove-Item $expansionStrings -Force
            Write-Host "remove expansions\strings.conf (stock captions restored)"
        } else {
            # No BOM: DataManager::LoadStrings does not skip one.
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllLines($expansionStrings, [string[]]$kept, $utf8NoBom)
            Write-Host "clean  expansions\strings.conf (stock captions restored)"
        }
    }
}

# --- Code list -------------------------------------------------------------
$codeList = Join-Path $generatedDir "Mayhem-codes.txt"
Copy-Item $codeList (Join-Path $GamePath "Mayhem-codes.txt") -Force
Write-Host "copy   Mayhem-codes.txt"

# --- Duel entry point ------------------------------------------------------
$bootstrap = Join-Path $repo "install\init.lua"
$installedInit = Join-Path $GamePath "init.lua"
if (Test-Path $installedInit) {
    $same = (Get-FileHash $installedInit).Hash -eq (Get-FileHash $bootstrap).Hash
    if (-not $same) {
        Copy-Item $installedInit "$installedInit.bak" -Force
        Write-Host "backup init.lua -> init.lua.bak (it was not ours)"
    }
}
Copy-Item $bootstrap $installedInit -Force
Write-Host "copy   init.lua"

# --- Banlists --------------------------------------------------------------
$banlists = Get-ChildItem (Join-Path $repo "install") -Filter *.lflist.conf -ErrorAction SilentlyContinue
foreach ($banlist in $banlists) {
    Copy-Item $banlist.FullName (Join-Path $GamePath "lflists\$($banlist.Name)") -Force
    Write-Host "copy   lflists\$($banlist.Name)"
}

Write-Host ""
Write-Host "Installed to $GamePath"

# Game::PopulateResourcesDirectories scans ./init.lua and expansions/script/ once,
# during startup. A client that was already open when this ran will not see the
# plugin at all for the rest of its session - the duel just keeps the typed code
# as its life points - so this warning matters more than it looks.
if (Get-Process EDOPro -ErrorAction SilentlyContinue) {
    Write-Host ""
    Write-Host "!! EDOPro is running. CLOSE AND REOPEN IT before hosting:" -ForegroundColor Yellow
    Write-Host "!! it only scans for the plugin at startup." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Host in LAN mode - a room hosted through Online Multiplayer runs on"
Write-Host "the remote server, where this plugin does not exist."
Write-Host ""
Write-Host "There is no menu to click. Pick a core by typing its number into"
Write-Host "LAN mode -> Create Host -> Duel tab -> Starting LP:"
Write-Host ""
# The core names are Vietnamese. Mayhem-codes.txt keeps them intact, but a
# classic Windows console cannot draw the diacritics whatever the code page is,
# so fold them for this printout only.
function Remove-Diacritics([string]$text) {
    $decomposed = $text.Replace([char]0x0110, 'D').Replace([char]0x0111, 'd')
    $decomposed = $decomposed.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($ch in $decomposed.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne
            [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($ch)
        }
    }
    return $builder.ToString()
}

[System.IO.File]::ReadAllLines($codeList, [System.Text.Encoding]::UTF8) |
    Select-Object -Skip 6 | ForEach-Object { Write-Host ("  " + (Remove-Diacritics $_)) }
Write-Host ""
Write-Host "The same list is at $GamePath\Mayhem-codes.txt"
Write-Host ""
Write-Host "Restart EDOPro if it was open while this ran."

