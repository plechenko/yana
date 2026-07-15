---
title: Blueprints and Modules
nav_order: 4
---

# Blueprints and Modules

## Blueprint

A **YANA Blueprint** is a YAML file (`.yana.yaml`) that describes your automation: its configuration, dependencies, routines and lifecycle events.

You are free to choose the structure of your blueprints - use a single file describing everything or split into multiple focused files.

### Blueprint Fields

A blueprint can define:

| Field | Description |
|---|---|
| `name` | Module name |
| `version` | Module version |
| `description` | Short description |
| `author` | Author name or contact |
| `license` | License identifier (e.g. `MIT`) |
| `dependencies` | List of modules this blueprint depends on |
| `routines` | Named sets of actions to execute |
| `events` | Lifecycle event handlers |

> Full schema reference is coming. Fields above reflect current understanding and are subject to change.

### Example Blueprint

```yaml
name: my-module
version: 1.0.0
description: Example YANA module
author: Your Name
license: MIT

dependencies:
  - source: https://github.com/oops-42/yana-modules
    module: common/apt

routines:
  .:
    - action: apt:install
      args:
        packages:
          - curl
          - git
```

## Module

A **YANA Module** is a directory containing a `.yana.yaml` blueprint file and any supporting files (scripts, templates, binaries, etc.).

### Module Structure

```
my-module/
  .yana.yaml          # blueprint file (required)
  .yanaignore         # list of files to exclude from yanapack (optional)
  .yana/              # directory for helpers, actions and verifiers
    helpers.sh
    actions.sh
    verifiers.sh
  templates/          # any other files your module needs
  files/
```

### .yanaignore

The `.yanaignore` file works like `.gitignore` and controls what gets excluded from the built yanapack.

By default, the following are always excluded:
- `.git`, `.gitignore`, `.yanaignore`, `.yana.yaml`
- `*.yanatests.sh`, `*.yanatests.ps1`

### Sub-modules

A module may contain sub-modules: sub-directories that have their own `.yana.yaml` file. The Toolkit resolves them recursively.

## Dependencies

Dependencies are declared in the blueprint and resolved by the Toolkit before packaging. Sources can be:

- A local path
- A Git repository URL

The Toolkit fetches all dependencies and bundles them into the yanapack so the target node does not need network access at apply time.
