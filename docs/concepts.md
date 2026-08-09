# YANA Concepts

This page explains the core components of YANA and how they fit together.

## YANA Engine

**YANA Engine** is an extremely lean and simple PowerShell/Bash script that runs directly on the target node.
Less than 500 lines of commented and unit-tested code with minimal dependencies.

**YANA Engine** works in 3 modes:

* `pull` - pulls a `yanapack` from a remote URL or uses local path
* `verify` - checks the state of the managed node against the `yanaspec`
* `apply` - applies the `yanapack` to the managed node

> It is the operator's responsibility to ensure that all requirements are met on the target node before applying a `yanapack`.

> **YANA Modules** may have additional requirements. Review the specification of each module for details. Particularly, `requires:` section.

## YANA Toolkit (In Future)

**YANA Toolkit** is an all-in-one tool for authoring blueprints. It runs on the developer's machine, not on the target node.

The Toolkit allows you to:

- Create and validate blueprints in YAML format
- Fetch all dependencies declared in a blueprint
- Run unit-tests for implemented functions using the [Testing Framework](testing.md)
- Compile the blueprint into a `yanaspec`
- Package everything into a `yanapack` for deployment

> The Engine does not need the Toolkit to be present on the target node.

### YANA Toolkit Requirements

=== "PowerShell (Windows)"

    - `YamlDotNet`
    - `git`

=== "Bash (Linux/macOS)"

    - `curl`
    - `tar`
    - `gzip`
    - `gunzip`
    - `base64`
    - `openssl`
    - `jq`
    - `yq`
    - `git`

## yanaspec

**yanaspec** is the compiled, resolved JSON document that YANA Engine reads and executes. It is produced from your blueprint by the Toolkit.

## yanapack (In Future)

A **yanapack** is a compressed, self-contained package created by the YANA Toolkit.

It contains:

- A `yanaspec` file (final JSON document derived from the blueprint, understood by YANA Engine)
- All required modules, scripts, templates, binaries and other assets

The target node only needs YANA Engine and the `yanapack`. No internet access or extra dependencies are required at apply time. You can audit the full contents of a yanapack before deploying it.
