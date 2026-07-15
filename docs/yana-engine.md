---
title: YANA Engine
nav_order: 8
---

# YANA Engine

**YANA Engine** is an extremely lean and simple PowerShell/Bash script that runs directly on the target node.
It fetches and applies a `yanapack` (bundled configuration and automation package) to the node.
Less than 500 lines of code with minimal dependencies.

- PowerShell version requires no additional tools beyond PowerShell itself.
- Bash version requires only `curl`, `tar`, `gunzip`, `base64` and `jq`.

The Engine does not need the Toolkit to be present on the target node. It only needs the `yanapack` file.

## YANA Engine CLI

**YANA Engine** provides a command-line interface `yana` which supports the following modes of operation:

- `apply` - fetches and applies a `yanapack` to the node. Read [yana apply](yana-apply.md) for details.
- `verify` - verifies that the node is in the desired state as defined by the `yanapack`. Read [yana verify](yana-verify.md) for details.
- `fetch` - fetches a `yanapack` from a remote source and saves it to a local file. Read [yana fetch](yana-fetch.md) for details.
