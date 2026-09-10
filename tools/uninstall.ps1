<#
.SYNOPSIS
    Removes the MD Mayhem plugin from an EDOPro / MDPro3 client.

.DESCRIPTION
    Reverses everything tools\install.ps1 does, and also cleans up what earlier
    versions of the plugin left behind when they still hijacked EDOPro's 13
    extra-rule checkboxes:

      - <GamePath>\expansions\script\mdmayhem\   the plugin folder
      - <GamePath>\init.lua                      the duel entry point
      - <GamePath>\lflists\Mayhem_Tactical.lflist.conf
      - <GamePath>\Mayhem-codes.txt
      - the "# >>> MD Mayhem" block in <GamePath>\expansions\strings.conf
        (the retitled Host window caption)

    init.lua is only deleted when it is ours. If install.ps1 had backed up a
    foreign init.lua to init.lua.bak, that file is put back.

    The installed mayhem_config.lua goes with the folder. It only holds settings
    that apply to every match, so reinstalling restores a working default.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1 -WhatIf
    powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1
    powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1 -GamePath "D:\EDOPro"

    With no -GamePath the script reuses the folder remembered by install.ps1, or
    asks which EDOPro install to clean.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GamePath
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "resolve-game-path.ps1")
$GamePath = Resolve-GamePath -GamePath $GamePath -Repo $repo -Remember:(-not $WhatIfPreference)

$pluginDir = Join-Path $GamePath "expansions\script\mdmayhem"
$removed = 0

# Read files through .NET rather than Get-FileHash / Select-String: those route
# through the provider stack, which prints its own noise under -WhatIf.
function Get-Sha256([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($path)))
    } finally {
        $sha.Dispose()
    }
}

# --- Plugin folder ---------------------------------------------------------
if (Test-Path $pluginDir) {
    if ($PSCmdlet.ShouldProcess($pluginDir, "Remove plugin folder")) {
        Remove-Item $pluginDir -Recurse -Force
        Write-Host "remove expansions\script\mdmayhem\"
        $removed++
    }
} else {
    Write-Host "skip   expansions\script\mdmayhem\ (not present)"
}

# install.ps1 creates expansions\script\ on the way in; a stock client has no
# such folder, so take it back out when nothing else moved in there.
$expansionsScript = Join-Path $GamePath "expansions\script"
if ((Test-Path $expansionsScript) -and
    -not (Get-ChildItem $expansionsScript -Force -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($expansionsScript, "Remove empty folder")) {
        Remove-Item $expansionsScript -Force
        Write-Host "remove expansions\script\ (left empty)"
        $removed++
    }
}

# --- Duel entry point ------------------------------------------------------
# Only ours may be deleted: another tool may legitimately own ./init.lua.
$installedInit = Join-Path $GamePath "init.lua"
$shippedInit = Join-Path $repo "install\init.lua"
$backupInit = "$installedInit.bak"
$installedInitIsOurs = $false

if (Test-Path $installedInit) {
    $installedInitIsOurs = (Test-Path $shippedInit) -and
                           ((Get-Sha256 $installedInit) -eq (Get-Sha256 $shippedInit))
    if ($installedInitIsOurs) {
        if ($PSCmdlet.ShouldProcess($installedInit, "Remove duel entry point")) {
            Remove-Item $installedInit -Force
            Write-Host "remove init.lua"
            $removed++
        }
    } else {
        Write-Host "keep   init.lua (not ours - left untouched)"
    }
}

if (Test-Path $backupInit) {
    # Another tool may have replaced init.lua after Mayhem was installed. Never
    # overwrite that newer owner: leave both it and our backup in place for the
    # operator to reconcile manually.
    if ((Test-Path $installedInit) -and (-not $installedInitIsOurs)) {
        Write-Host "keep   init.lua.bak (current init.lua belongs to something else)"
    } elseif ($PSCmdlet.ShouldProcess($backupInit, "Restore backed-up init.lua")) {
        Move-Item $backupInit $installedInit -Force
        Write-Host "restore init.lua from init.lua.bak"
    }
}

# --- Banlist ---------------------------------------------------------------
foreach ($banlist in Get-ChildItem (Join-Path $repo "install") -Filter *.lflist.conf -ErrorAction SilentlyContinue) {
    $target = Join-Path $GamePath "lflists\$($banlist.Name)"
    if (Test-Path $target) {
        if ($PSCmdlet.ShouldProcess($target, "Remove banlist")) {
            Remove-Item $target -Force
            Write-Host "remove lflists\$($banlist.Name)"
            $removed++
        }
    }
}

# --- Code list -------------------------------------------------------------
$codeList = Join-Path $GamePath "Mayhem-codes.txt"
if (Test-Path $codeList) {
    if ($PSCmdlet.ShouldProcess($codeList, "Remove code list")) {
        Remove-Item $codeList -Force
        Write-Host "remove Mayhem-codes.txt"
        $removed++
    }
}

# --- Interface strings -----------------------------------------------------
# Our block retitles the Host window (and, in older versions, renamed the Extra
# Rules checkboxes). Drop only that block; anything else in the file is not ours.
$expansionStrings = Join-Path $GamePath "expansions\strings.conf"
if (Test-Path $expansionStrings) {
    $kept = @()
    $inBlock = $false
    $found = $false
    foreach ($line in Get-Content $expansionStrings) {
        if ($line -eq "# >>> MD Mayhem") { $inBlock = $true; $found = $true; continue }
        if ($line -eq "# <<< MD Mayhem") { $inBlock = $false; continue }
        if (-not $inBlock) { $kept += $line }
    }
    if ($found) {
        if (($kept | Where-Object { $_.Trim() -ne "" }).Count -eq 0) {
            if ($PSCmdlet.ShouldProcess($expansionStrings, "Remove strings file")) {
                Remove-Item $expansionStrings -Force
                Write-Host "remove expansions\strings.conf (only held our block)"
                $removed++
            }
        } elseif ($PSCmdlet.ShouldProcess($expansionStrings, "Strip Mayhem block")) {
            # No BOM: DataManager::LoadStrings does not skip one.
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllLines($expansionStrings, [string[]]$kept, $utf8NoBom)
            Write-Host "clean  expansions\strings.conf (stock labels restored)"
            $removed++
        }
    }
}

Write-Host ""
if ($WhatIfPreference) {
    Write-Host "Dry run - nothing was changed. Re-run without -WhatIf to apply."
} elseif ($removed -eq 0) {
    Write-Host "Nothing to remove - $GamePath is already clean."
} else {
    Write-Host "MD Mayhem removed from $GamePath. Restart EDOPro to drop the loaded scripts."
}
