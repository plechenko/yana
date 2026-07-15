---
title: Getting Started
nav_order: 2
---

# Getting Started

> Note: YANA is under active development. This document reflects the current state of the project.

## Prerequisites

YANA has minimal dependencies by design.

### PowerShell (Windows)

- PowerShell 5.1 or later (built into Windows)
- `git` (required by YANA Toolkit only)
- `YamlDotNet` (required by YANA Toolkit only)

### Bash (Linux/macOS)

- Bash 4.0 or later
- `curl`, `tar`, `gunzip`, `base64`, `jq` (required by YANA Engine)
- `git`, `gzip`, `yq` (required by YANA Toolkit only)

## Installation

YANA consists of standalone scripts. There is no installer.

1. Download `yana.sh` (Bash) or `yana.ps1` (PowerShell) from the [releases page](https://github.com/oops-42/yana/releases) or clone the repository.
2. Place the script in a directory on your `PATH`, or reference it directly.

```bash
# Clone the repository
git clone https://github.com/oops-42/yana.git
cd yana
```

## Running YANA

Apply a blueprint to the current node:

```bash
# Bash
./yana.sh

# PowerShell
./yana.ps1
```

Specify a blueprint file:

```bash
./yana.sh -blueprint ./my-blueprint.yana.yaml
```

Run a specific routine:

```bash
./yana.sh -routine setup
```

## Running the Testing Framework

To run tests for your actions and helpers:

```bash
# Bash - run all tests in current directory
./yana-test.sh

# PowerShell - run all tests in current directory
./yana-test.ps1
```

See the [Testing Framework](testing.md) documentation for full usage.
