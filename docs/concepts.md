---
title: Concepts
nav_order: 3
---

# Concepts

This page explains the core components of YANA and how they fit together.

## Overview

```
[Blueprint + Modules]
        |
        v
[YANA Toolkit] --> compiles --> [yanapack]
                                    |
                                    v
                              [YANA Engine] --> applies to --> [Node]
```

## YANA Engine

**YANA Engine** is an extremely lean and simple PowerShell/Bash script that runs directly on the target node.
It fetches and applies a `yanapack` (bundled configuration and automation package) to the node.
Less than 500 lines of code with minimal dependencies.

- PowerShell version requires no additional tools beyond PowerShell itself.
- Bash version requires only `curl`, `tar`, `gunzip`, `base64` and `jq`.

The Engine does not need the Toolkit to be present on the target node. It only needs the `yanapack` file.

## YANA Toolkit

**YANA Toolkit** is an all-in-one tool for authoring blueprints. It runs on the developer's machine, not on the target node.

The Toolkit allows you to:

- Create and validate blueprints
- Fetch all dependencies declared in a blueprint
- Unit-test actions and helpers using the [Testing Framework](testing.md)
- Compile the blueprint into a `yanaspec`
- Package everything into a `yanapack` for deployment

Dependencies:
- PowerShell version requires `git` and `YamlDotNet`.
- Bash version requires `git`, `curl`, `tar`, `gzip`, `base64`, `jq` and `yq`.

## yanapacks

A **yanapack** is a compressed, self-contained package produced by the YANA Toolkit.

It contains:
- A `yanaspec` file (final JSON document derived from the blueprint, understood by YANA Engine)
- All required modules, scripts, templates, binaries and other assets

The target node only needs YANA Engine and the `yanapack`. No internet access or extra dependencies are required at apply time. You can audit the full contents of a yanapack before deploying it.

## yanaspec

**yanaspec** is the compiled, resolved JSON document that YANA Engine reads. It is produced from your blueprint by the Toolkit. You do not write yanaspec directly.
