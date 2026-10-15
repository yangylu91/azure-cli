---
name: search-api-version-cut
description: "Use when adding a new Azure AI Search management-plane (Microsoft.Search RP) API version to the `az search` module: regenerate AAZ commands from the merged azure-rest-api-specs version, reconcile custom.py, re-record tests, and prepare the PR. Search-specific; module is core `search`."
argument-hint: "Provide the API version (e.g. 2026-11-01), whether it is GA or preview, and the merged azure-rest-api-specs PR or commit."
---

# Search Management API Version Cut (az search)

Workflow for bringing `az search` up to a new Microsoft.Search ARM API version. The module stays in core azure-cli: `src/azure-cli/azure/cli/command_modules/search`.

Commands are generated from the swagger/TypeSpec in `azure-rest-api-specs`. The Python management SDK is **not** a dependency of generated commands.

## Inputs

```yaml
api_version: "<e.g. 2026-11-01 or 2026-11-01-preview>"
spec_ref: "<merged azure-rest-api-specs PR number or commit SHA>"
track: "<ga | preview>"
```

Resolve from the prompt. Ask only if `api_version` or `spec_ref` is missing.

## Safety

- Follow `.github/instructions/agent-safety.instructions.md`; keep edits inside this repo.
- Never edit files under `aaz/latest` by hand. They are generated; custom behavior goes in `custom.py`.
- Never edit `HISTORY.rst`. Release notes come from the PR title/description (see `.github/instructions/history-rst.instructions.md`).

## Phase 0: Preflight

1. Spec is merged and the folder exists: `specification/search/resource-manager/Microsoft.Search/Search/{stable|preview}/<api_version>`. Check with `gh pr view <n> -R Azure/azure-rest-api-specs --json state,mergedAt`.
2. Current module version: `Select-String '"version"' src/azure-cli/azure/cli/command_modules/search/aaz/latest/search/service/_create.py`.
3. Run `scripts/preflight.ps1` from this skill folder. It reports a missing venv, `azdev`, `aaz-dev`, or missing `aaz` / `azure-rest-api-specs` clones.
4. Base the work on up-to-date upstream `dev`, on a `feature-*`-prefixed or personal branch. The agreed personal branch is `search/mgmt-cli`.

Stop and report if the RP is not deployed to the regions used for live recording (tests would fail).

## Phase 1: Environment

Needs sibling clones (outside this repo) of `Azure/aaz` and `Azure/azure-rest-api-specs`, plus a Python 3.10-3.14 venv with:

```powershell
pip install azdev aaz-dev
azdev setup --cli <path-to-azure-cli> --repo <path-to-azure-rest-api-specs>
```

Starting aaz-dev (UI at http://127.0.0.1:5000):

```powershell
aaz-dev run -c <azure-cli> -m <aaz-repo> -s <azure-rest-api-specs> --cli-path <azure-cli>
```

## Phase 2: Update command models (aaz-dev UI, human in the loop)

In the Workspace Editor:

1. Create a workspace for `search` from the swagger/TypeSpec for `<api_version>`, or open the existing one.
2. Add/replace the resources for the `Microsoft.Search/searchServices` family (service, admin keys, query keys, private endpoint connections, private link resources, shared private link resources, network security perimeter configurations) using the new version.
3. Review new properties/arguments and any removed or renamed ones. Flag breaking changes to the user before continuing.
4. Export the workspace to the `aaz` repo.

Do not hand-edit the `aaz` repo models.

## Phase 3: Generate CLI code

In the CLI Generator, choose module `search` in azure-cli, select the commands, pick `<api_version>`, and generate. Check the diff under `command_modules/search/aaz/latest`:

- `"version": "<api_version>"` updated for every operation.
- No unrelated modules changed.

Mark new GA/preview status appropriately: commands/arguments for preview versions are marked `is_preview`.

## Phase 4: Reconcile custom code

Customization lives in `custom.py` as subclasses of generated classes, currently `SearchServiceCreate` and `SearchServiceUpdate`. Follow `.github/skills/common-aaz-custom-code-generation/SKILL.md` and the `custom-code` agent.

Checklist:

- Every `args_schema.<name>` referenced in `_build_arguments_schema` still exists after regeneration (for example `ip_rules_internal`, `api_key_only`, `upgrade_available`, `endpoint`). Renamed or removed arguments will raise `AttributeError` at load time.
- `pre_operations` validations (hosting mode vs sku, `--disable-local-auth` vs `--auth-options`, ip-rules parsing) match the new model shape.
- New service properties from the spec that deserve a first-class argument are listed for the user rather than silently added.
- Update `_help.py` for new arguments; update `_params.py` / `commands.py` only if needed.
- Check `linter_exclusions.yml` for stale entries.

## Phase 5: Tests

Tests are in `search/tests/latest` with recordings in `recordings/`.

1. Update tests for any new behavior.
2. Re-record against the new API version: `azdev test search --live` (use the eastus2euap cloud if the version is not yet in production; register with `az cloud register ...` and `az cloud set`).
3. Confirm recordings now contain `api-version=<api_version>`; delete obsolete recordings.
4. Run playback: `azdev test search`.

## Phase 6: Validate and PR

```powershell
azdev style search
azdev linter search
azdev test search
```

PR to `Azure/azure-cli` `dev`:

- Title: `[Search] Add API version <api_version>` (`[Component]` prefix makes it a customer-facing history note; use `{Search}` to exclude).
- Fill the PR template, including the History Notes section.
- Request the CLI team contact as reviewer (azpycli@microsoft.com).

## Output

Report: version change, files changed by area (generated vs custom vs tests), customization changes, test results, and open questions (new args to expose, breaking changes, RP deployment status).

## Known limitations

- The aaz-dev model step (Phase 2) is interactive; this skill does not drive the UI.
- Whether to migrate `search` to an extension (azure-cli-extensions) is an open team decision; this skill assumes the core module.
