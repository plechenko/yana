---
title: Routines and Events
nav_order: 6
---

# Routines and Events

## Routines

**YANA Routines** are named sets of actions executed together as a single unit.

Routines are declared in the blueprint. You can call one routine from another.
When running `yana`, you specify which routine to execute:

```bash
./yana.sh -routine setup
```

### Dot-routine

The dot-routine (`"."`) is the default routine. It is executed if no `-routine` argument is specified:

```bash
./yana.sh
# equivalent to: ./yana.sh -routine .
```

Use routines to organize your blueprint into smaller, focused and reusable units.

### Example

```yaml
routines:
  .:
    - routine: install
    - routine: configure

  install:
    - action: apt:install
      args:
        packages: [nginx]

  configure:
    - action: file:copy
      args:
        src: templates/nginx.conf
        dest: /etc/nginx/nginx.conf
```

## Events

**YANA Events** are lifecycle hooks that run at specific points during blueprint execution.

| Event | When it fires |
|---|---|
| `pre-apply` | Before applying the blueprint |
| `post-apply` | After the blueprint is applied successfully |
| `on-success` | When execution completes without errors |
| `on-error` | When an error occurs during execution |

Use events to:
- Notify users or services about progress
- Perform pre-apply checks (disk space, network connectivity, etc.)
- Perform post-apply cleanup
- Trigger alerts on failure

### Example

```yaml
events:
  pre-apply:
    - action: notify:slack
      args:
        message: "Applying blueprint on {{ hostname }}"

  on-error:
    - action: notify:slack
      args:
        message: "Blueprint failed on {{ hostname }}: {{ error }}"

  post-apply:
    - action: notify:slack
      args:
        message: "Blueprint applied successfully on {{ hostname }}"
```
