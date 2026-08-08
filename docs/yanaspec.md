# YANA Spec Format

**YANA Spec** is a JSON file (`<name>.yana.json`) that instructs YANA Engine how to apply your automation. YANA Engine uses this file to execute your automation on the target node.

## Sections

YANA Spec includes sections: metadata, requires, params, vars, steps.

### Metadata

Metadata section contains information about the spec itself, such as name, version, description, author, license.

| Field | Description |
| --- | --- |
| `name` | Module name |
| `version` | Module version |
| `description` | Short description |
| `author` | Author name or contact |
| `license` | License identifier (e.g. `MIT`) |

### Requires

Requires section lists the requirements that must be satisfied on the target node before applying the spec.
It includes a list of required tools.

```json title="Example"
"requires": [
    "git",
    "curl",
    "tar",
    "gzip",
    "base64",
    "jq"
]
```

### Params

Params section defines the parameters that the spec accepts.
Each parameter has a name (alphanumeric with underscores) and default value.
The param values can be overridden at apply time.
Params can be referenced using `${param:<param_name>}` syntax.

```json title="Example"
"params": {
    "nginx_port": 8080,
    "nginx_user": "www-data",
    "nginx_group": "${param:nginx_user}$"
}
```

### Vars

Vars section defines variables that are used in the spec.
Each variable has a name (alphanumeric with underscores) and value.
Variables, in contrast to params, are not overridden at apply time.
They are used to store intermediate values or computed results.

Variable values can be static or dynamic.

* Static variables have literal or composed values.
* Dynamic variables call declared functions with arguments to compute their values at runtime.
Dynamic variables are evaluated Just-In-Time (JIT) when they are referenced in args.
Dynamic variables can be cached to avoid repeated computation and lookup queries.
Dynamic variables can be marked as secret to avoid unexpected leakage by logging their values in the output.

Dynamic variables are defined as objects with:

| Field | Type | Description |
| --- | --- | --- |
| `fn` | string | Reference to the `yanavar`-function in format: `[module/]script:function` |
| `args` | object | (Optional) Arguments for the function |
| `cached` | boolean | (Optional) Whether to cache the result |
| `secret` | boolean | (Optional) Whether the result is secret and should not be logged |

Variables can be referenced using `${var:<var_name>}` syntax.

```json title="Example"
"vars": {
    "static_var": "value",
    "composed_var": "prefix_${param:nginx_user}_${var:static_var}",
    "dynamic_var": {
        "fn": "compute:value",
        "args": {
            "param1": "value1"
        },
        "cached": true,
        "secret": true
    }
}
```

In the example above:
* `static_var` is a static variable with a literal value.
* `composed_var` is a composed variable that combines static values and other variables.
* `dynamic_var` is a dynamic variable computed at runtime by calling the function `yanavar_value` located in script `compute.sh` or `compute.ps1` (depending on the platform) with argument `param1` set to `value1`.

### Steps

Steps section defines the list of actions that YANA Engine will perform to apply or validate the state.
All steps executed sequentially in the order they are defined.

Each step has:

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | (Optional) Step name |
| `apply` | string | Reference to the `yanaapply`-function in format: `[module/]script:function`.<br>If omitted, the step will not perform `apply` action. |
| `verify` | string | Reference to the `yanaverify`-function in format: `[module/]script:function`.<br>If omitted, the step will use the `apply` function. If empty or "-", the step will not perform `verify` action |
| `args` | object | (Optional) Arguments for the action |
| `if` | string/array | (Optional) Condition(s) to execute the step. |
| `if_not` | string/array | (Optional) Condition(s) to skip the step. |

> Step shall include at least one of `apply` or `verify` fields. If both are omitted, the step will be skipped.
