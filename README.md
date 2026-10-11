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
| `agents-policy.tf` | Agent/MCP rules (server allowlist, unsupervised DELETE/UPDATE) |

## Prerequisites

- Terraform >= 1.0
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

After the first `apply`, verify in the Infinity portal that the rule
evaluation order (`order`, first-match) produces the expected behavior: the
more specific allow/block rules (Claude, Gemini, DELETE/UPDATE block) must
precede the generic catch-alls.

## Using the Workforce AI MCP server

The project-scoped [`.mcp.json`](.mcp.json) configures Check
Point's official [`@chkp/workforce-ai-mcp`](https://github.com/CheckPointSW/workforce-ai-mcp)
server. Use it with Claude Code or another MCP client to retrieve the
Claude/Gemini app IDs and DLP data type IDs needed for setup. These lookups
are part of the repository's setup workflow; the server queries your tenant
without requiring manual `curl` calls to the APIs described above.

The MCP server is read-only in this workflow. Terraform is the single
source of truth for the policy.

1. Ask the agent to look up an application or data type, for example
  "find the app_id for Claude". It uses the MCP server's
  `search_apps` / `get_apps_by_ids` (app catalog) or
   `search_dlp_datatypes` / `get_tenant_dlp_datatypes` (DLP data types)
  tools to query your live tenant, then writes the returned values into
  your local `terraform.tfvars`. Keep these values out of committed files:
  the IDs are tenant-specific rather than secrets, but `.tfvars` remains
  gitignored.
2. Once `terraform.tfvars` has real values, run `plan` and `apply` as usual
  (see [Usage](#usage)). The MCP server does not change the live policy.
3. Leave write mode off. The server's `WRITE_MODE` environment variable
  allows an agent to create, edit, or delete tenant rules directly.
  `.mcp.json` omits it, so it defaults to `false`. Direct changes bypass
  the reviewable, versioned Terraform plan. Enable it in this repo's
  `.mcp.json` only for a specific, reviewed reason.

For setup, export `CP_CI_CLIENT_ID`, `CP_CI_ACCESS_KEY` (same values as
`checkpoint_client_id`/`checkpoint_access_key`), and `CP_CI_GATEWAY`
(`https://cloudinfra-gw.portal.checkpoint.com` for `eu`,
`https://cloudinfra-gw-us.portal.checkpoint.com` for `us`) in the shell your
agent/editor runs in, then restart it to load the MCP server configuration.
`.mcp.json` references `${CP_CI_CLIENT_ID}` and the other environment
variables; it contains no literal credentials.

## Dangerous scenarios covered

| Rule | Scenario | Mitigation |
|------|----------|------------|
| `block_credit_card_prompt` / `_upload` | An employee pastes or uploads a customer's payment data into an AI tool | Block (`prevent`) on any service |
| `redact_secrets_prompt` | A developer pastes code with a hardcoded API key/credential into a prompt | Automatic redaction (`redact`) |
| `block_ssn_prompt` / `_upload` (disabled by default) | An employee pastes or uploads a customer/employee Social Security Number | Block (`prevent`) on any service, once a real `ssn_data_type_id` is set |
| `block_iban_prompt` / `_upload` (disabled by default) | An employee pastes or uploads a bank account/IBAN number | Block (`prevent`) on any service, once a real `iban_data_type_id` is set |
| `block_generic_paste_example` (disabled) | A user pastes an entire confidential document with no recognized DLP pattern | Full paste block - aggressive, evaluate before enabling |
| `block_destructive_operations` | An AI agent invokes an MCP tool with an unsupervised `DELETE` operation | Blocks `DELETE` operations on all MCP servers |
| `ask_on_update_operations` | An AI agent invokes an MCP tool with an unsupervised `UPDATE` operation | Requires explicit user confirmation before `UPDATE` operations |
| `block_unlisted_mcp_servers` | An employee connects an unverified third-party MCP server (tool poisoning / supply chain) | Blocks every non-whitelisted MCP server |
| `ask_other_genai` | Use of shadow AI (a GenAI tool other than Claude/Gemini) | Requires explicit user confirmation |

## Extending the policy

- To block/allow other AI tools: add more `cpwai_workforce_ai_access_rule`
  resources with an `order` lower than the catch-all (`ask_other_genai`,
  currently `order = 2`).
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
- Respect first-match ordering. This provider evaluates rules by
  ascending `order`; the first match wins. Put the most specific rules
  (approved tools, destructive-operation blocks) before generic catch-alls,
  and verify the effective order in the Infinity portal after every
  `apply`. Terraform won't catch a logical ordering mistake.
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
- Keep file protection enabled for approved tools. Approved
  tools (Claude, Gemini) still get `upload_file_protection` /
  `download_file_protection` set to `"enabled"`, not `"na"`, so their file
  transfers remain monitored.
- Review disabled example and optional rules before enabling them.
  `block_generic_paste_example`, `block_ssn_prompt`/`_upload`, and
  `block_iban_prompt`/`_upload` ship `active = false` because they are
  either aggressive (generic paste block) or need a tenant-specific data
  type ID you must supply. Evaluate impact in `ask` mode or with a small
  pilot group first.
