---
title: Functions
nav_order: 5
---

# Functions: Helpers, Actions, Verifiers

YANA functions are pure PowerShell/Bash functions organized into script files. There are three types.

## Types

### Helpers

**YANA Helpers** are small utility functions used to add dynamism to blueprints.
They compute values, transform data, or perform lookups - they do not modify system state.

### Actions

**YANA Actions** are functions that perform specific tasks within a blueprint.
They modify system state (install packages, write files, start services, etc.).

### Verifiers

**YANA Verifiers** check the state of the system before or after applying actions.
They are used to achieve idempotency - an action is only applied if the verifier determines it is needed.

Verifiers are optional companions to Actions. A verifier paired with an action allows YANA Engine to skip the action if the desired state is already present.

## Location

Scripts containing helpers, actions and verifiers are stored in the `.yana/` directory of the module and are automatically loaded by YANA Engine when the module is applied.

```
my-module/
  .yana/
    helpers.sh      # or helpers.ps1
    actions.sh      # or actions.ps1
    verifiers.sh    # or verifiers.ps1
```

There is no enforced file naming inside `.yana/`. All `.sh` (or `.ps1`) files are loaded.

## Writing Functions

YANA does not impose a special DSL. Functions are plain PowerShell/Bash.

Bash example:

```bash
# Helper
yana_get_os() {
    uname -s
}

# Action
yana_install_package() {
    local package="$1"
    apt-get install -y "$package"
}

# Verifier
yana_is_package_installed() {
    local package="$1"
    dpkg -s "$package" >/dev/null 2>&1
}
```

PowerShell example:

```powershell
# Helper
function Get-OsName {
    [System.Environment]::OSVersion.Platform
}

# Action
function Install-Package {
    param([string]$Name)
    choco install $Name -y
}

# Verifier
function Test-PackageInstalled {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}
```

## Module Repository

YANA does not ship built-in helpers, actions or verifiers. You declare the modules you need in your blueprint.

The [YANA Modules Repository](https://github.com/oops-42/yana-modules) contains a collection of reusable modules.
You can also create your own modules and share them.

## Testing Functions

Write unit tests for your functions using the [YANA Testing Framework](testing.md).
