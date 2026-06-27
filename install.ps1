<#
.SYNOPSIS
    PPT Master - one-shot installer for the Claude Code skill (Windows / PowerShell).

.DESCRIPTION
    1. Copies skills\ppt-master into %USERPROFILE%\.claude\skills\ppt-master
    2. Creates an isolated Python venv at ...\ppt-master\.venv
    3. Installs the Python dependencies into that venv

    It does NOT touch your global Python, and never copies your .env / API keys.

.EXAMPLE
    git clone https://github.com/msjh172-ship-it/ppt-master.git
    cd ppt-master
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

$ErrorActionPreference = 'Stop'

Write-Host "==> PPT Master installer (Windows)"

$SkillName  = 'ppt-master'
$SkillsDir  = Join-Path $env:USERPROFILE '.claude\skills'
$Dest       = Join-Path $SkillsDir $SkillName
$ScriptDir  = $PSScriptRoot
$Src        = Join-Path $ScriptDir "skills\$SkillName"

# --- locate Python 3 ---------------------------------------------------------
$PythonCmd = $null
if (Get-Command py -ErrorAction SilentlyContinue) {
    try { & py -3 --version *> $null; if ($LASTEXITCODE -eq 0) { $PythonCmd = @('py', '-3') } } catch {}
}
if (-not $PythonCmd) {
    foreach ($c in @('python', 'python3')) {
        if (Get-Command $c -ErrorAction SilentlyContinue) { $PythonCmd = @($c); break }
    }
}
if (-not $PythonCmd) {
    Write-Error "Python 3 not found. Install Python 3.10+ (https://www.python.org/downloads/) and re-run."
    exit 1
}
$PyExe  = $PythonCmd[0]
$PyPre  = if ($PythonCmd.Count -gt 1) { $PythonCmd[1..($PythonCmd.Count - 1)] } else { @() }
Write-Host ("    Python: " + (& $PyExe @PyPre --version 2>&1))

# --- sanity check source -----------------------------------------------------
if (-not (Test-Path $Src)) {
    Write-Error "Skill source not found at $Src`nRun this script from the repo root (the folder containing skills\ppt-master)."
    exit 1
}

# --- copy skill files --------------------------------------------------------
Write-Host "==> Copying skill files -> $Dest"
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
# robocopy: /E recurse, exclude venv/cache dirs and pyc/.env files. Exit codes 0-7 = success.
robocopy $Src $Dest /E /XD .venv __pycache__ /XF *.pyc .env /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Error "robocopy failed (exit $LASTEXITCODE)"; exit 1 }
$global:LASTEXITCODE = 0

# --- create venv + install deps ---------------------------------------------
Write-Host "==> Creating virtual environment"
& $PyExe @PyPre -m venv (Join-Path $Dest '.venv')

$VenvPy = Join-Path $Dest '.venv\Scripts\python.exe'
Write-Host "==> Installing dependencies (this can take a few minutes)"
& $VenvPy -m pip install --upgrade pip
& $VenvPy -m pip install -r (Join-Path $Dest 'requirements.txt')

# --- verify ------------------------------------------------------------------
Write-Host "==> Verifying key packages"
$check = @'
import importlib.util
mods = ["pptx", "fitz", "PIL", "flask", "edge_tts", "requests",
        "bs4", "svglib", "reportlab", "openpyxl", "numpy"]
missing = [m for m in mods if importlib.util.find_spec(m) is None]
print("    OK - all key packages importable" if not missing
      else "    MISSING: " + ", ".join(missing))
'@
& $VenvPy -c $check

Write-Host ""
Write-Host "Done."
Write-Host "  Skill installed at : $Dest"
Write-Host "  venv interpreter   : $VenvPy"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  - Restart Claude Code so it picks up the 'ppt-master' skill."
Write-Host "  - (Optional) For cloud image / TTS backends, create $Dest\.env"
Write-Host "    using $Dest\.env.example as a template."
