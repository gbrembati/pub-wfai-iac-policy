# Workforce AI - Baseline Policy (Terraform)

Terraform baseline for a Check Point Workforce AI tenant, using
the provider [`CheckPointSW/checkpoint-workforce-ai`](https://registry.terraform.io/providers/CheckPointSW/checkpoint-workforce-ai/latest/docs).

Claude and Google Gemini are the approved GenAI tools. Other tools in the
"Generative AI" category require explicit user confirmation, allowing a
gradual rollout without a hard block. DLP and Agents rules address data and
PII leakage, credentials in source code, and agent/MCP abuse.

## Files

| File | Content |
|------|---------|
| `provider.tf` | `cpwai` provider configuration |
| `variables.tf` | Input variables (credentials, app IDs, data type IDs) |
| `terraform.tfvars.example` | Template to copy into `terraform.tfvars` |
| `access-policy.tf` | Allow Claude/Gemini + "ask" on everything else |
| `dlp-policy.tf` | DLP rules for dangerous scenarios (credit cards, secrets, SSN, IBAN) |
| `agents-policy.tf` | Agent/MCP rules (server allowlist, DELETE/UPDATE blocks) |
| `tests/policy.tftest.hcl` | Offline policy contract tests using a mocked provider |

## Prerequisites

- Terraform >= 1.17.1 and < 2.0.0 (current stable release: 1.17.1)
- Check Point Workforce AI provider ~> 1.0.2 (selected version in `.terraform.lock.hcl`)
- An Infinity Portal account with a Workforce AI license
- An API key with the Workforce AI Security service (Settings -> API Keys -> New -> New Account API Key)

## Steps to do BEFORE the first `apply`

Retrieve the tenant-specific values below before applying the policy.
The provider does not publish them as static defaults.

### 1. Claude and Gemini application IDs

The `genai_application.id` field identifies an application in your tenant's
AI catalog. The project-scoped [`.mcp.json`](.mcp.json) connects to Check Point's
official MCP server for these lookups. See
[Using the Workforce AI MCP server](#using-the-workforce-ai-mcp-server)
for setup, then choose either method below.

Option A: use the MCP server (recommended).
Ask your agent to look up an app ID, for example "find the app_id for Claude".
It uses the server's `search_apps` / `get_apps_by_ids` tools to query your
live tenant. Write the returned `app_id` into `claude_app_id` /
`gemini_app_id` in `terraform.tfvars`.

Option B: use the [Apps Catalog API](https://app.swaggerhub.com/apis/Check-Point/checkpoint-ai-security/1.0.0#/Apps%20Catalog)
(`POST /app/genai-protect-apps/external/v1/apps/search`, bearer-authenticated
with a JWT obtained from your `checkpoint_client_id`/`checkpoint_access_key`):

```
POST /app/genai-protect-apps/external/v1/apps/search
{ "search": "Claude", "search_by": "name" }

POST /app/genai-protect-apps/external/v1/apps/search
{ "search": "Gemini", "search_by": "name" }
```

Use the `app_id` field from the matching entry in the response's `results`
array as the value for `claude_app_id` / `gemini_app_id`.

### 2. DLP data types (Secrets/API Keys, SSN, IBAN)

The "Credit Card Number" data type is predefined and its UUID
(`cf0523c1-537e-4a4b-8bb8-084b7b9e0b45`) is already set as the default.
`secrets_data_type_id` defaults to the tenant's predefined "Credentials"
type. Override it with a `CUSTOM` type's UUID if you need broader coverage,
such as raw source code.

There is no predefined data type for SSN or IBAN: each must be created as a
`CUSTOM` type at the tenant level via the
[DLP Datatypes API](https://app.swaggerhub.com/apis/Check-Point/checkpoint-ai-security/1.0.0#/DLP%20Datatypes),
then its UUID goes into `ssn_data_type_id` / `iban_data_type_id`
respectively. These rules are disabled (`active = false`) until you provide
real IDs. See [Best practices](#best-practices) before enabling them.

### 3. Internal MCP domain

Set `internal_mcp_domain` to the domain (or suffix) used by your authorized
internal company MCP servers.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# fill in terraform.tfvars with your data (see above)

export TF_VAR_checkpoint_client_id="..."
export TF_VAR_checkpoint_access_key="..."
# or leave them in terraform.tfvars - DO NOT commit it

terraform init
terraform plan
terraform apply
```

Rule positions in the rule base are not set by this configuration: `order`
is optional in the provider, so new rules are placed by the backend. After the
first `apply`, arrange and verify the rule evaluation order (first-match) in
the Infinity portal: the more specific allow/block rules (Claude, Gemini,
DELETE/UPDATE block) must precede the generic catch-alls.

### Upgrading an existing checkout

Install [Terraform 1.17.1](https://developer.hashicorp.com/terraform/install)
or a newer compatible release before running:

```bash
terraform init -upgrade
terraform validate
terraform test
terraform plan
```

Review the plan before applying it. Version constraints do not install or
upgrade the Terraform CLI. Keep `.terraform.lock.hcl` in version control;
normal `terraform init` reuses its provider selection, while `-upgrade`
selects the newest provider allowed by the constraint.

The [provider changes from 1.0.0 to 1.0.2](https://github.com/CheckPointSW/terraform-provider-checkpoint-workforce-ai/compare/v1.0.0...v1.0.2)
clarify two backend constraints:

- Agents/MCP actions support only `block` and `allow`, not `ask`. The UPDATE
  rule now uses `block`, including for supervised operations. Its Terraform
  address remains `ask_on_update_operations` to preserve existing state
  identity. The DELETE/UPDATE blocks must precede the internal allowlist and
  catch-all in the rule base.
- Workforce AI access/chat scopes must use
  `services_and_application.mode = "selected"`. The existing category
  `60531762` wildcard already matches any AI app. `genai_application.mode =
  "all"` still means all accounts for that app and is unchanged. Access
  rules still support `ask`.

`terraform test` uses a mocked provider with dummy credentials and app IDs;
it checks the policy JSON and does not contact or change the tenant.

## Using the Workforce AI MCP server

The project-scoped [`.mcp.json`](.mcp.json) configures Check
Point's official [`@chkp/workforce-ai-mcp`](https://github.com/CheckPointSW/workforce-ai-mcp)
server. Use it with Claude Code or another MCP client to retrieve the
Claude/Gemini app IDs and DLP data type IDs needed for setup. These lookups
are part of the repository's setup workflow; the server queries your tenant
without requiring manual `curl` calls to the APIs described above.

Terraform is the single source of truth for the policy. Use MCP only for
lookups in this workflow. The `.mcp.json` sets `WRITE_MODE = "false"`, so the
server runs read-only and hides every tool that can change the tenant (see
[Write mode](#write-mode)).

The command is `npx --yes @chkp/workforce-ai-mcp@latest`. As documented by
[npm](https://docs.npmjs.com/cli/v11/commands/npx#description), an unversioned
package name can reuse a locally installed dependency. The explicit
`@latest` suffix requests the npm `latest` dist-tag instead; it is part of
the package name, not a separate `latest` argument. The current tag is
`1.2.7` (checked on 2026-11-02), independently of the Terraform provider's
version. npm may reuse cached files for the resolved version. Restart the
MCP server to resolve a new release; an already running process does not
update itself. For reproducible deployments, pin an exact package version
instead of `@latest`.

1. Ask the agent to look up an application or data type, for example
  "find the app_id for Claude". It uses the MCP server's
  `search_apps` / `get_apps_by_ids` (app catalog) or
   `search_dlp_datatypes` / `get_tenant_dlp_datatypes` (DLP data types)
  tools to query your live tenant, then writes the returned values into
  your local `terraform.tfvars`. Keep these values out of committed files:
  the IDs are tenant-specific rather than secrets, but `.tfvars` remains
  gitignored.
2. Once `terraform.tfvars` has real values, run `plan` and `apply` as usual
  (see [Usage](#usage)). Lookup tools do not change the live policy.
For setup, copy `.env.example` to `.env` and fill in `CP_CI_CLIENT_ID` and
`CP_CI_ACCESS_KEY` (same values as `checkpoint_client_id`/`checkpoint_access_key`).
`.env` is gitignored. `.mcp.json` starts the server through `sh`, which
sources `./.env` from the project root before running `npx`, so no manual
`export` is needed. Each line of `.env` must be a valid shell assignment
(`KEY=value`); quote values that contain spaces or special characters.
Reconnect the MCP server (for example `/mcp` in Claude Code) after editing
`.env`. `.mcp.json` contains no credentials.
`CP_CI_GATEWAY` defaults to the EU endpoint,
`https://cloudinfra-gw.portal.checkpoint.com`, in `.mcp.json`. For a US tenant,
set `CP_CI_GATEWAY=https://cloudinfra-gw-us.portal.checkpoint.com` in `.env`;
values in `.env` take precedence over the defaults in `.mcp.json`.

### Write mode

`WRITE_MODE` controls whether the server exposes its write tools
(`create_*`, `delete_*`, `set_*`, `patch_*`, `reorder_rule`,
`update_*_object`). Only the exact value `"true"` (case-insensitive) enables
them; any other value, or omitting the variable, keeps the server read-only.

| Value | Effect |
|-------|--------|
| `"false"` (default in `.mcp.json`) | Read-only: only lookup and reporting tools are available |
| `"true"` | The agent can create, modify, reorder, and delete tenant rules and objects |

To enable write mode, change the value in `.mcp.json` to `"true"` and
reconnect the MCP server. To enable it only for yourself without changing the
tracked file, add `WRITE_MODE=true` to your `.env` instead. Changes made
through MCP bypass the reviewable, versioned Terraform plan and drift from the
Terraform state, so the next `terraform apply` may revert them. Enable write
mode only for a specific, reviewed reason, and turn it off afterwards.

## Dangerous scenarios covered

| Rule | Scenario | Mitigation |
|------|----------|------------|
| `block_credit_card_prompt` / `_upload` | An employee pastes or uploads a customer's payment data into an AI tool | Block (`prevent`) on any service |
| `redact_secrets_prompt` | A developer pastes code with a hardcoded API key/credential into a prompt | Automatic redaction (`redact`) |
| `block_ssn_prompt` / `_upload` (disabled by default) | An employee pastes or uploads a customer/employee Social Security Number | Block (`prevent`) on any service, once a real `ssn_data_type_id` is set |
| `block_iban_prompt` / `_upload` (disabled by default) | An employee pastes or uploads a bank account/IBAN number | Block (`prevent`) on any service, once a real `iban_data_type_id` is set |
| `block_generic_paste_example` (disabled) | A user pastes an entire confidential document with no recognized DLP pattern | Full paste block - aggressive, evaluate before enabling |
| `block_destructive_operations` | An AI agent invokes an MCP tool with an unsupervised `DELETE` operation | Blocks `DELETE` operations on all MCP servers |
| `ask_on_update_operations` (legacy Terraform address) | An AI agent invokes an MCP tool with an `UPDATE` operation | Blocks all matching `UPDATE` operations; Agents/MCP does not support `ask` |
| `block_unlisted_mcp_servers` | An employee connects an unverified third-party MCP server (tool poisoning / supply chain) | Blocks every non-whitelisted MCP server |
| `ask_other_genai` | Use of shadow AI (a GenAI tool other than Claude/Gemini) | Requires explicit user confirmation |

## Extending the policy

- To block/allow other AI tools: add more `cpwai_workforce_ai_access_rule`
  resources and place them above the catch-all (`ask_other_genai`) in the
  rule base. You can optionally pin a position with the `order` attribute.
- For other DLP data types beyond SSN/IBAN: look them up with the DLP
  Datatypes API and add new rules in `dlp-policy.tf` following the same
  pattern.
- For browser security (not just Workforce AI chat/agent), see the
  provider's `cpwai_browse_*` resources (not included in this baseline).

## Best practices

- Roll out new restrictions gradually with `ask` before `prevent`. Start
  with a new tool or DLP data type in `ask` mode and review the logs for
  false positives before switching to `block`/`prevent`. The baseline uses
  this approach for `ask_other_genai`.
- Respect first-match ordering. Rules are evaluated by ascending position
  in the rule base; the first match wins. Put the most specific rules
  (approved tools, destructive-operation blocks) before generic catch-alls,
  and verify the effective order in the Infinity portal after every
  `apply`. This configuration does not set `order`, so Terraform won't catch
  a logical ordering mistake.
- Keep `logging = "enabled"` on every rule. All baseline rules log by
  default, including `allow` rules. Use those logs to validate a rollout
  before tightening restrictions.
- Never commit secrets. `terraform.tfvars` and Terraform state can contain
  the API client ID/access key. Keep both covered by `.gitignore` and prefer
  environment variables (`TF_VAR_*`) or a secret manager over a checked-in
  `.tfvars` file.
- Re-check tenant-specific IDs. `claude_app_id`, `gemini_app_id`, and custom
  DLP data type IDs come from your tenant and can change if the catalog is
  reorganized. Verify them at setup and after changes on the Check Point side.
- Apply least privilege to MCP servers. Use an explicit allowlist
  (`allow_internal_mcp_only`) instead of broad allow rules. Evaluate the
  destructive/unsupervised-operation blocks (`DELETE`, `UPDATE`) before
  the allowlist so they also cover trusted internal servers if compromised.
- Keep `upload_file_protection` / `download_file_protection` set to `"na"`
  on Workforce AI access rules, as required by the
  [provider schema](https://github.com/CheckPointSW/terraform-provider-checkpoint-workforce-ai/blob/v1.0.2/docs/resources/cpwai_workforce_ai_access_rule.md).
  File upload DLP is handled by the separate chats rules.
- Review disabled example and optional rules before enabling them.
  `block_generic_paste_example`, `block_ssn_prompt`/`_upload`, and
  `block_iban_prompt`/`_upload` ship `active = false` because they are
  either aggressive (generic paste block) or need a tenant-specific data
  type ID you must supply. Evaluate impact in `ask` mode or with a small
  pilot group first.
