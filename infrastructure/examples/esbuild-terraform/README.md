# esbuild + Terraform Example

## Overview

This example shows how to replace the shell script (`build-lambdas.sh`) and
Terragrunt `before_hook` with Terraform-native build and packaging using
`null_resource` + `data.archive_file`.

## How It Works

```bash
┌─────────────────────────────────────────────────────────────────┐
│ Terraform Plan/Apply                                            │
│                                                                 │
│  1. hash_file("./src/**/*.ts")  ← detects source changes       │
│  2. null_resource "build"       ← runs esbuild only if changed │
│  3. data.archive_file           ← creates zip from dist/       │
│  4. aws_lambda_function         ← deploys if zip hash changed  │
└─────────────────────────────────────────────────────────────────┘
```

### Current Flow (3 build layers)

```bash
Terragrunt before_hook → build-lambdas.sh (shell, 337 lines)
  → npm run build (esbuild via scripts/build.ts)
  → zip via shell/archiver
→ Terraform reads zip via filebase64sha256()
```

### Proposed Flow (Terraform-native)

```bash
Terraform:
  null_resource "build" (triggers on source hash)
    → npm run build (esbuild via scripts/build.ts)
  data.archive_file (creates zip from dist/)
  aws_lambda_function (deploys, change detection via source_code_hash)
```

## What This Eliminates

- `scripts/build-lambdas.sh` (337-line shell script)
- `.lambda-build-cache/` directory and hash files
- Terragrunt `before_hook "build_lambdas"` in app.hcl
- `scripts/package.ts` (archiver-based zip creation)

## What This Keeps

- `scripts/build.ts` (esbuild bundler) — already fast and well-structured
- `npm run build` command — still used, just triggered differently

## Trade-offs

### Pros

- Single source of truth for change detection (Terraform state)
- No external cache files or shell script complexity
- `archive_file` handles zip creation natively
- Works with `terraform plan` — shows when rebuild will happen

### Cons

- Build runs inside Terraform's plan/apply lifecycle (via provisioner)
- `null_resource` with `local-exec` is less portable than external builds
- Can't easily run the build *outside* of Terraform (e.g., for testing)
- `archive_file` re-zips every plan (cheap, but not zero-cost)

## Recommendation

For your project (5-6 lambdas, small team, Terragrunt wrapper), the current
approach is actually solid — the shell script adds robustness (hash caching,
dependency install, error handling) that `null_resource` can't easily replicate.

Consider this approach if:

- You want to remove the shell script entirely
- You're moving away from Terragrunt hooks
- You want Terraform to own the full lifecycle

Stick with the current approach if:

- The shell script/hook is working well
- You need `npm ci` to run conditionally (null_resource can't do this cleanly)
- You want builds decoupled from Terraform lifecycle
