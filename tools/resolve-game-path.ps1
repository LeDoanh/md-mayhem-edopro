<#
.SYNOPSIS
    Works out which EDOPro / MDPro3 install to act on.

.DESCRIPTION
    Dot-sourced by install.ps1 and uninstall.ps1 so both resolve the target the
    same way. Resolution order:

      1. an explicit -GamePath argument
      2. the path remembered from last time (<repo>\.game-path)
      3. a scan of the fixed drives, then a prompt

    The confirmed path is remembered, so it is asked for once per machine.
    Non-interactive runs never prompt: they fail with an explanation instead, so
    a script can never silently install into the wrong folder.
#>

function Test-GameFolder {
    param([string]$Path)
    return $Path -and (Test-Path (Join-Path $Path "EDOPro.exe"))
}

function Find-GameFolders {
    <#
        Looks for EDOPro.exe up to three levels below each fixed drive root, which
        covers the usual shapes (D:\EDOPro, F:\Game\ProjectIgnis, C:\Program
        Files\EDOPro). Plain globbing, no recursive walk, so it stays quick.
    #>
    $patterns = foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        if (-not $drive.Root -or $drive.Root -notmatch '^[A-Za-z]:\\$') { continue }
        foreach ($depth in 1..3) {
            $wildcards = ("*\" * $depth)
            "$($drive.Root)$wildcards" + "EDOPro.exe"
        }
    }

    $found = foreach ($pattern in $patterns) {
        Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue |
            ForEach-Object { $_.DirectoryName }
    }
    return @($found | Sort-Object -Unique)
}

function Resolve-GamePath {
    param(
        [string]$GamePath,
        [Parameter(Mandatory)][string]$Repo,
        [bool]$Remember = $true
    )

    $memory = Join-Path $Repo ".game-path"

    # 1. Explicit argument wins, and is remembered for next time.
    if ($GamePath) {
        if (-not (Test-GameFolder $GamePath)) {
            throw "EDOPro.exe not found in '$GamePath'."
        }
        $resolved = (Resolve-Path $GamePath).Path
        if ($Remember) {
            Set-Content -Path $memory -Value $resolved -Encoding ascii -WhatIf:$false
        }
        return $resolved
    }

    # 2. Whatever was confirmed last time, as long as it is still there.
    if (Test-Path $memory) {
        $remembered = (Get-Content $memory -TotalCount 1).Trim()
        if (Test-GameFolder $remembered) {
            Write-Host "Game folder: $remembered  (remembered; override with -GamePath)"
            return $remembered
        }
        Write-Host "Remembered folder '$remembered' is gone - looking again."
    }

    # 3. Scan, then ask.
    Write-Host "Looking for EDOPro..."
    # PowerShell unrolls a one-element array on return, so force it back.
    $candidates = @(Find-GameFolders)

    if ([Console]::IsInputRedirected) {
        if ($candidates.Count -eq 1) {
            Write-Host "Game folder: $($candidates[0])  (only match found)"
            if ($Remember) {
                Set-Content -Path $memory -Value $candidates[0] -Encoding ascii -WhatIf:$false
            }
            return $candidates[0]
        }
        $hint = if ($candidates.Count -eq 0) { "none found" } else { $candidates -join "; " }
        throw ("Cannot ask for the game folder in a non-interactive run. " +
               "Pass -GamePath <folder>. Candidates: $hint")
    }

    if ($candidates.Count -gt 0) {
        Write-Host ""
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $candidates[$i])
        }
        Write-Host ""
        $answer = Read-Host "Pick a number, or paste the folder that holds EDOPro.exe"
    } else {
        Write-Host "No EDOPro install found automatically."
        $answer = Read-Host "Paste the folder that holds EDOPro.exe"
    }

    $answer = $answer.Trim().Trim('"')
    $chosen = $null
    $index = 0
    if ([int]::TryParse($answer, [ref]$index) -and $index -ge 1 -and $index -le $candidates.Count) {
        $chosen = $candidates[$index - 1]
    } elseif ($answer) {
        $chosen = $answer
    }

    if (-not (Test-GameFolder $chosen)) {
        throw "EDOPro.exe not found in '$chosen'."
    }

    $chosen = (Resolve-Path $chosen).Path
    if ($Remember) {
        Set-Content -Path $memory -Value $chosen -Encoding ascii -WhatIf:$false
    }
    Write-Host "Game folder: $chosen  (remembered for next time)"
    return $chosen
}
