# YANA - Yet Another Node Automator

**YANA** is an extremely small and simple, yet powerful, extensible Configuration Management and Automation tool written in pure PowerShell (for Windows systems) and Bash (for Unix-like systems).
No magic, no hidden dependencies, no black boxes, no new programming language to learn.
Just PowerShell/Bash, YAML and your favorite text editor.

**YANA** is designed to be lightweight, simple, fast and easy to use.

## YANA Principles

We value the following principles when designing and implementing **YANA**:

* **KISS** - *Keep It Simple and Stupid.* YANA is designed to be simple, small and easy to use.
* **YAGNI** - *You Ain't Gonna Need It.* YANA is designed to be minimalistic and focused on the core functionality.
No unnecessary features, no bloat, no complexity.
It's easy to introduce the new features and functionality, but very difficult to deprecate and remove them.
* **DRY** - *Don't Repeat Yourself.* YANA is designed to be modular and reusable.
Don't reinvent the wheel - use existing actions, helpers, functions, blueprints and projects.
Keep your blueprints and projects small, modular, focused and reusable.

> The descriptions and statements below are not final and may be subject to change.

## YANA Engine

**YANA Engine** is an extremely lean and simple PowerShell/Bash script running on the node.
It fetches and applies so-called `yanapacks`(the bundled configs and automations) to a target node.
Less than 500 lines of code with minimal dependencies.

* PowerShell version does not require any additional tools.
* Bash version only requires `curl`, `tar`, `gunzip`, `base64` and `jq`.

## YANA Toolkit

**YANA Toolkit** is an all-in-one toolkit for authoring blueprints.
It allows you to create blueprints, fetch all dependencies, unit-test actions and helpers, compile, package and publish yanapacks.

* PowerShell version requires `git` and `YamlDotNet`.
* Bash version requires only `git`, `curl`, `tar`, `gzip`, `base64`, `jq` and `yq`.

## YANA Blueprints and Modules

**YANA Blueprints** are YAML files that define configuration parameters, routines, lifecycle events and dependencies.
You are free to choose a structure of your blueprints - use a single huge blueprint describing everything or split into multiple small and focused blueprints.

In blueprint you can define:

* metadata (name, version, description, author, license, etc.)
* sources of your dependencies (local path/git repository) and their composition (order of execution)
* managed routines and conditions
* lifecycle events.

**YANA Module** is a directory containing a `.yana.yaml` blueprint file and optionally other files (scripts, templates, files, binaries, etc.) required by the blueprint.

**YANA Module** may contain a `.yanaignore` file with a list of files and directories to be ignored when building the yanapack (similar to `.gitignore`). By default, the following files and directories are ignored: `.git`, `.gitignore`, `.yanaignore`, `.yana.yaml`, `*.yanatests.sh`, `*.yanatests.ps1`.

**YANA Module** may also contain sub-modules (sub-directories with their own `.yana.yaml` files).

**YANA Toolkit** reads the blueprint to resolve all dependencies, compiles yanaspec (final JSON document used by **YANA Engine**) and packages them into a bundled `yanapack` file. `yanapack` is a compressed package containing `yanaspec` file and all required modules, templates, scripts, binaries and other assets of composed projects. It is applied by **YANA Engine** on the target node without need to fetch any additional dependencies. You have full control over the content of the `yanapack` and can easily audit it before applying on the target node.

## YANA Functions: Helpers, Actions and Verifiers

**YANA Helpers**, **YANA Actions** and **YANA Verifiers** are pure PowerShell/Bash functions organized into scripts (`.sh` or `.ps1` files containing these functions).

* **YANA Helpers** are small utility functions used to add dynamism to blueprints.
* **YANA Actions** are functions that perform specific tasks or operations within a blueprint. They modify the system state.
* **YANA Verifiers** are functions that check the state of the system or validate the results of actions. They verify that the system is in the desired state before or after applying the actions. **YANA Verifiers** are optional companions to **YANA Actions**, they are used to achieve idempotency and audit the system state.

Scripts containing **YANA Helpers**, **YANA Actions** and **YANA Verifiers** are stored in the `.yana` directory of the **YANA Module** and are automatically loaded by **YANA Engine** when applying the blueprint.

YANA itself does not include any helpers, actions or verifiers. Instead, you declare in your blueprint which modules you want to include and use. There is a [YANA Module Repository](https://github.com/oops-42/yana-modules) with a collection of modules that you can use in your blueprints. You can also create your own modules and share them with others.

## YANA Routines

**YANA Routines** are sets of actions that are executed together as a single unit. Routines are named and can be called from other routines. While executing `yana`, you can specify which routine to execute. There is also a special dot-routine (`"."`) that is executed by default if no routine is specified. Use routines to organize your blueprint into smaller, focused and reusable units.

## YANA Events

**YANA Events** are lifecycle events that can be defined in the blueprint. They are used to trigger actions and verifiers at specific points in the blueprint execution. You can use events to notify users about progress and state via your messenger, perform pre-apply checks (i.e. free disk space, network connectivity, etc.), perform post-apply cleanup or any other actions you want to implement.

The following events are supported:

* `pre-apply` - triggered before applying the blueprint.
* `post-apply` - triggered after applying the blueprint.
* `on-error` - triggered when an error occurs during the blueprint execution.
* `on-success` - triggered when the blueprint execution is successful.

## YANA Testing Framework

YANA includes Testing Framework that allows you to write unit tests for your actions, helpers and verifiers. Tests are written in PowerShell/Bash and can be executed using the `yana-test` command (later `yana-tool test`).

All YANA internal functions are unit-tested using the YANA Testing Framework. You can use read the code and tests to learn how to use YANA Testing Framework to write your own tests for your actions, helpers and verifiers.

Current documentation for YANA Testing Framework is available in the [YANA Tests](docs/yanatests.md) document.

## Contributing

You can contribute to **YANA** and **YANA Modules** by submitting issues and feature requests, proposing code improvements as pull requests, contributing into [YANA Modules Repository](https://github.com/oops-42/yana-modules), sharing and showcasing your experience with **YANA** and **YANA Modules**.

All contributions are welcome. We encourage you to follow the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/) when contributing to **YANA** and **YANA Modules**.

## License

**YANA** and **YANA Modules** are licensed under the [MIT License](https://opensource.org/licenses/MIT). See the [LICENSE](LICENSE) file for details.

By contributing to **YANA** and **YANA Modules**, you agree that your contributions will be also licensed under the [MIT License](https://opensource.org/licenses/MIT).
