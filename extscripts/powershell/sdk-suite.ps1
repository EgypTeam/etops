<#  sdksuite.ps1  (Windows-native)
    CLI contract:
      sdksuite --list
      sdksuite --list <meta-sdk>
      sdksuite install <meta-sdk>
      sdksuite install <meta-sdk>/<sdk>/<version>
      sdksuite uninstall <meta-sdk>
      sdksuite uninstall <meta-sdk>/<sdk>/<version>
      sdksuite reinstall <meta-sdk>
      sdksuite reinstall <meta-sdk>/<sdk>/<version>
      sdksuite install --all / uninstall --all / reinstall --all
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- Config (adjust if you prefer D:\ or something else)
$SDK_ROOT = "C:\development\sdk"
$BASHRCD = Join-Path $HOME ".bashrc.d"   # used only for Git-Bash integration helpers (optional)

$DOTNET_DIR = Join-Path $SDK_ROOT "dotnet\dotnet"         # mirror your Linux layout idea
$NVM_DIR    = Join-Path $SDK_ROOT "nvm"
$PYENV_DIR  = Join-Path $SDK_ROOT "pyenv"
$SWI_DIR    = Join-Path $SDK_ROOT "swi-prolog"

$SUITE_BIN  = Join-Path $SDK_ROOT "sdksuite\bin"

function Die($msg) { throw "ERROR: $msg" }
function Info($msg) { Write-Host $msg }

function Ensure-Dir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

function Ensure-Path-User([string]$dir) {
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($null -eq $current) { $current = "" }
  $parts = $current.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() }
  if (-not ($parts -contains $dir)) {
    $new = ($parts + $dir) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $new, "User")
    Info "Added to USER PATH: $dir"
  }
}

function Ensure-Command([string]$cmd) {
  $found = Get-Command $cmd -ErrorAction SilentlyContinue
  return ($null -ne $found)
}

function Winget-Install([string]$id) {
  if (-not (Ensure-Command "winget")) {
    Die "winget not found. Install App Installer (Microsoft Store) or enable winget."
  }
  Info "winget install: $id"
  winget install --id $id -e --accept-package-agreements --accept-source-agreements | Out-Null
}

function Winget-Uninstall([string]$id) {
  if (-not (Ensure-Command "winget")) { Die "winget not found." }
  Info "winget uninstall: $id"
  winget uninstall --id $id -e | Out-Null
}

# -----------------------
# Meta SDK definitions
# -----------------------
$META_ALL = @("dotnet", "nvm", "pyenv", "swi", "sdkman", "rbenv", "phpbrew", "ruby")
# On Windows, sdkman/rbenv/phpbrew are not native. We keep them in the interface but explain/redirect.

function Meta-List {
  @("dotnet","nvm","pyenv","ruby","php","swi") | ForEach-Object { $_ }
}

function List-Dotnet {
  if (Ensure-Command "dotnet") { & dotnet --list-sdks } else { "dotnet not on PATH (run: sdksuite install dotnet)" }
}

function List-Nvm {
  if (Ensure-Command "nvm") { & nvm list } else { "nvm-windows not on PATH (run: sdksuite install nvm)" }
}

function List-Pyenv {
  if (Ensure-Command "pyenv") { & pyenv versions } else { "pyenv-win not on PATH (run: sdksuite install pyenv)" }
}

function List-Swi {
  if (Test-Path (Join-Path $SWI_DIR "current\bin\swipl.exe")) {
    & (Join-Path $SWI_DIR "current\bin\swipl.exe") --version
  } elseif (Ensure-Command "swipl") {
    & swipl --version
  } else {
    "SWI-Prolog not found (run: sdksuite install swi)"
  }
}

# -----------------------
# Install meta SDKs
# -----------------------

function Install-Dotnet {
  Ensure-Dir $DOTNET_DIR
  Ensure-Path-User $DOTNET_DIR
  # For global tools path:
  $dotnetTools = Join-Path $HOME ".dotnet\tools"
  Ensure-Dir $dotnetTools
  Ensure-Path-User $dotnetTools

  # Provide dotnet-install.ps1 under SDK_ROOT for leaf installs
  $installer = Join-Path $SDK_ROOT "dotnet\dotnet-install.ps1"
  if (-not (Test-Path $installer)) {
    Ensure-Dir (Split-Path $installer -Parent)
    Info "Downloading dotnet-install.ps1 to $installer"
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $installer
  }

  Info "dotnet meta-sdk ready. (Leaf install supported: dotnet/sdk/<version>)"
}

function Install-Nvm {
  Ensure-Dir $NVM_DIR
  # nvm-windows is typically installed system-wide; use winget for bootstrap
  # ID may vary, but this is the commonly used winget id:
  Winget-Install "CoreyButler.NVMforWindows"
  Info "nvm meta-sdk ready. (Leaf install supported: nvm/node/<version>)"
}

function Install-Pyenv {
  Ensure-Dir $PYENV_DIR
  # pyenv-win via winget
  Winget-Install "pyenv-win.pyenv-win"
  Info "pyenv meta-sdk ready. (Leaf install supported: pyenv/python/<version>)"
}

function Install-Ruby {
  # Windows Ruby version management is not as standard; start with RubyInstaller + optional uru later
  Winget-Install "RubyInstallerTeam.RubyWithDevKit"
  Info "ruby meta-sdk installed (RubyInstaller). Multi-version switching on Windows needs a chosen strategy (uru/asdf on MSYS2/WSL)."
}

function Install-Php {
  # PHP on Windows: simplest bootstrap via winget (often installs a single PHP)
  # If you want multi-version: Scoop is the usual strategy.
  Winget-Install "PHP.PHP"
  Info "php meta-sdk installed (single PHP). For multi-version switching on Windows, prefer Scoop-based PHP installs."
}

function Install-Swi {
  # SWI-Prolog official installer via winget
  Winget-Install "SWI-Prolog.SWI-Prolog"
  Info "swi meta-sdk installed. For your Linux-style /versions/current layout on Windows, we can add a Windows swi-mgr later (PowerShell)."
}

function Install-Meta([string]$meta) {
  switch ($meta) {
    "dotnet" { Install-Dotnet }
    "nvm"    { Install-Nvm }
    "pyenv"  { Install-Pyenv }
    "ruby"   { Install-Ruby }
    "php"    { Install-Php }
    "swi"    { Install-Swi }
    "sdkman" { Die "sdkman is Linux/WSL-first. Use WSL or Git-Bash+WSL. On Windows-native, use winget/java distributions instead." }
    "rbenv"  { Die "rbenv is not Windows-native. Use WSL, or a Windows Ruby strategy (RubyInstaller + uru)." }
    "phpbrew"{ Die "phpbrew is not Windows-native. Use WSL, or a Windows PHP strategy (Scoop recommended)." }
    default  { Die "Unknown meta-sdk: $meta" }
  }
}

function Uninstall-Meta([string]$meta) {
  switch ($meta) {
    "nvm"   { Winget-Uninstall "CoreyButler.NVMforWindows" }
    "pyenv" { Winget-Uninstall "pyenv-win.pyenv-win" }
    "ruby"  { Winget-Uninstall "RubyInstallerTeam.RubyWithDevKit" }
    "php"   { Winget-Uninstall "PHP.PHP" }
    "swi"   { Winget-Uninstall "SWI-Prolog.SWI-Prolog" }
    "dotnet"{
      Info "dotnet uninstall: removing PATH entries is manual; SDKs live under $DOTNET_DIR. Delete folder if you want."
    }
    default { Die "Unknown meta-sdk: $meta" }
  }
}

# -----------------------
# Leaf install/uninstall
# -----------------------
function Install-Leaf([string]$spec) {
  $parts = $spec.Split('/')
  if ($parts.Length -ne 3) { Die "Expected <meta-sdk>/<sdk>/<version>: $spec" }
  $meta,$sdk,$ver = $parts[0],$parts[1],$parts[2]

  switch ($meta) {
    "dotnet" {
      if ($sdk -ne "sdk") { Die "dotnet leaf format: dotnet/sdk/<version>" }
      $installer = Join-Path $SDK_ROOT "dotnet\dotnet-install.ps1"
      if (-not (Test-Path $installer)) { Install-Dotnet }
      Ensure-Dir $DOTNET_DIR
      Info "Installing .NET SDK $ver into $DOTNET_DIR"
      & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Version $ver -InstallDir $DOTNET_DIR
      return
    }
    "nvm" {
      if ($sdk -ne "node") { Die "nvm leaf format: nvm/node/<version>" }
      if (-not (Ensure-Command "nvm")) { Install-Nvm }
      & nvm install $ver
      return
    }
    "pyenv" {
      if ($sdk -ne "python") { Die "pyenv leaf format: pyenv/python/<version>" }
      if (-not (Ensure-Command "pyenv")) { Install-Pyenv }
      & pyenv install $ver
      return
    }
    default {
      Die "Leaf install not implemented for: $meta/$sdk/$ver (Windows variant)."
    }
  }
}

function Uninstall-Leaf([string]$spec) {
  $parts = $spec.Split('/')
  if ($parts.Length -ne 3) { Die "Expected <meta-sdk>/<sdk>/<version>: $spec" }
  $meta,$sdk,$ver = $parts[0],$parts[1],$parts[2]

  switch ($meta) {
    "dotnet" {
      if ($sdk -ne "sdk") { Die "dotnet leaf format: dotnet/sdk/<version>" }
      $dir = Join-Path $DOTNET_DIR "sdk\$ver"
      if (-not (Test-Path $dir)) { Die "dotnet SDK not found: $dir" }
      Remove-Item -Recurse -Force $dir
      Info "Removed dotnet SDK $ver"
      return
    }
    "nvm" {
      if ($sdk -ne "node") { Die "nvm leaf format: nvm/node/<version>" }
      & nvm uninstall $ver
      return
    }
    "pyenv" {
      if ($sdk -ne "python") { Die "pyenv leaf format: pyenv/python/<version>" }
      & pyenv uninstall $ver
      return
    }
    default {
      Die "Leaf uninstall not implemented for: $meta/$sdk/$ver (Windows variant)."
    }
  }
}

# -----------------------
# CLI
# -----------------------
function Help {
@"
sdksuite (Windows native)

Commands:
  sdksuite --list
  sdksuite --list <meta-sdk>

  sdksuite install <meta-sdk>
  sdksuite install <meta-sdk>/<sdk>/<version>
  sdksuite install --all

  sdksuite uninstall <meta-sdk>
  sdksuite uninstall <meta-sdk>/<sdk>/<version>
  sdksuite uninstall --all

  sdksuite reinstall <meta-sdk>
  sdksuite reinstall <meta-sdk>/<sdk>/<version>
  sdksuite reinstall --all

Windows-supported leaf formats:
  dotnet/sdk/<version>
  nvm/node/<version>
  pyenv/python/<version>

Note:
  sdkman/rbenv/phpbrew are Linux/WSL-first.
"@ | Write-Host
}

function List-Meta([string]$arg) {
  if ([string]::IsNullOrWhiteSpace($arg)) { Meta-List; return }
  switch ($arg) {
    "dotnet" { List-Dotnet; return }
    "nvm"    { List-Nvm; return }
    "pyenv"  { List-Pyenv; return }
    "swi"    { List-Swi; return }
    "ruby"   { if (Ensure-Command "ruby") { ruby -v } else { "ruby not found (sdksuite install ruby)" }; return }
    "php"    { if (Ensure-Command "php") { php -v } else { "php not found (sdksuite install php)" }; return }
    default  { Die "Unknown meta-sdk for list: $arg" }
  }
}

function Install-All { @("dotnet","nvm","pyenv","ruby","php","swi") | ForEach-Object { Info "==> install $_"; Install-Meta $_ } }
function Uninstall-All { @("dotnet","nvm","pyenv","ruby","php","swi") | ForEach-Object { Info "==> uninstall $_"; Uninstall-Meta $_ } }
function Reinstall-All { Uninstall-All; Install-All }

# Entry
if ($args.Count -eq 0) { Help; exit 0 }

$cmd = $args[0]
$rest = @()
if ($args.Count -gt 1) { $rest = $args[1..($args.Count-1)] }

switch ($cmd) {
  "--list" {
    if ($rest.Count -gt 1) { Die "Usage: sdksuite --list [meta-sdk]" }
    $m = if ($rest.Count -eq 1) { $rest[0] } else { "" }
    List-Meta $m
    break
  }
  "install" {
    if ($rest.Count -ne 1) { Die "Usage: sdksuite install <meta-sdk | meta/sdk/ver | --all>" }
    $what = $rest[0]
    if ($what -eq "--all") { Install-All; break }
    if ($what -match ".+/.+/.+") { Install-Leaf $what; break }
    Install-Meta $what
    break
  }
  "uninstall" {
    if ($rest.Count -ne 1) { Die "Usage: sdksuite uninstall <meta-sdk | meta/sdk/ver | --all>" }
    $what = $rest[0]
    if ($what -eq "--all") { Uninstall-All; break }
    if ($what -match ".+/.+/.+") { Uninstall-Leaf $what; break }
    Uninstall-Meta $what
    break
  }
  "reinstall" {
    if ($rest.Count -ne 1) { Die "Usage: sdksuite reinstall <meta-sdk | meta/sdk/ver | --all>" }
    $what = $rest[0]
    if ($what -eq "--all") { Reinstall-All; break }
    if ($what -match ".+/.+/.+") { Uninstall-Leaf $what; Install-Leaf $what; break }
    Uninstall-Meta $what
    Install-Meta $what
    break
  }
  "help" { Help; break }
  default { Die "Unknown command: $cmd (try: sdksuite help)" }
}
