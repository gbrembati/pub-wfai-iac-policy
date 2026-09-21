# Workforce AI - Baseline Policy (Terraform)

Baseline policy for the Check Point **Workforce AI** tenant, managed through
the provider [`CheckPointSW/checkpoint-workforce-ai`](https://registry.terraform.io/providers/CheckPointSW/checkpoint-workforce-ai/latest/docs).

Goal: **Claude** and **Google Gemini** are the approved GenAI tools; any other
tool in the "Generative AI" category requires explicit user confirmation (no
hard block, for a gradual rollout). It also covers a few common dangerous
scenarios (data/PII leakage, secrets/source code leakage, agent/MCP abuse)
through DLP and Agents rules.

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
- An Infinity Portal account with a **Workforce AI** license
- An API key with the **Workforce AI Security** service (Settings -> API Keys -> New -> New Account API Key)

## Steps to do BEFORE the first `apply`

Some values are not statically published by the provider and must be
retrieved from your tenant. They are not made up: they are left as variables
for you to fill in.

### 1. Claude and Gemini application IDs

The `genai_application.id` field refers to your tenant's AI catalog.
Retrieve it with the [Apps Catalog API](https://app.swaggerhub.com/apis/Check-Point/checkpoint-ai-security/1.0.0#/Apps%20Catalog)
(`POST /app/genai-protect-apps/external/v1/apps/search`, bearer-authenticated
with a JWT obtained from your `checkpoint_client_id`/`checkpoint_access_key`):

```
POST /app/genai-protect-apps/external/v1/apps/search
{ "search": "Claude", "search_by": "name" }

POST /app/genai-protect-apps/external/v1/apps/search
{ "search": "Gemini", "search_by": "name" }
```

Each match in the response's `results` array has an `app_id` field - that's
the value for `claude_app_id` / `gemini_app_id` (in `terraform.tfvars`).
Easier: use the [Workforce AI MCP server](#using-the-workforce-ai-mcp-server-optional-for-ai-agents)
below and have an agent look it up for you instead of crafting this call by
hand.

### 2. DLP data types (Secrets/API Keys, SSN, IBAN)

The "Credit Card Number" data type is predefined and its UUID
(`cf0523c1-537e-4a4b-8bb8-084b7b9e0b45`) is already set as the default.
`secrets_data_type_id` also has a working default out of the box: the
tenant's predefined "Credentials" type. Override it with a `CUSTOM` type's
UUID only if you need broader coverage later (e.g. raw source code).

There is no predefined data type for SSN or IBAN: each must be created as a
`CUSTOM` type at the tenant level via the
[DLP Datatypes API](https://app.swaggerhub.com/apis/Check-Point/checkpoint-ai-security/1.0.0#/DLP%20Datatypes),
then its UUID goes into `ssn_data_type_id` / `iban_data_type_id`
respectively. Those rules are shipped **disabled** (`active = false`) until
you provide real IDs - see [Best practices](#best-practices).

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

## Using the Workforce AI MCP server (optional, for AI agents)

This repo ships a project-scoped [`.mcp.json`](.mcp.json) that wires in Check
Point's official [`@chkp/workforce-ai-mcp`](https://github.com/CheckPointSW/workforce-ai-mcp)
server. It lets an AI coding agent (Claude Code or any other MCP client)
look up real tenant data directly, instead of you manually crafting `curl`
calls against the Apps Catalog / DLP Datatypes APIs described above.

**Division of labor:** the MCP server is for **read/lookup only** here -
Terraform stays the single source of truth for what the policy actually is.
Concretely:

1. **MCP reads, you/the agent fill in values.** Ask the agent to look up an
   application or data type (e.g. "find the app_id for Claude") and it calls
   the MCP server's `search_apps` / `get_apps_by_ids` (app catalog) or
   `search_dlp_datatypes` / `get_tenant_dlp_datatypes` (DLP data types)
   tools against your live tenant. The agent then writes the returned value
   into your local `terraform.tfvars` (never into files that get committed
   - the actual IDs are tenant-specific, not secrets, but `.tfvars` stays
   gitignored regardless).
2. **Terraform applies.** Once `terraform.tfvars` has real values, `plan`
   and `apply` as usual (see [Usage](#usage)). The MCP server never changes
   your live policy directly in this workflow.
3. **Write mode stays off.** The server supports a `WRITE_MODE` env var
   that lets an agent create/edit/delete rules directly against the tenant.
   `.mcp.json` intentionally omits it (defaults to `false`): letting an LLM
   mutate a live security policy outside of a reviewable, versioned
   Terraform plan defeats the point of managing it as IaC. Don't enable it
   in this repo's `.mcp.json` unless you have a specific, reviewed reason
   to.

**Setup:** export `CP_CI_CLIENT_ID`, `CP_CI_ACCESS_KEY` (same values as
`checkpoint_client_id`/`checkpoint_access_key`), and `CP_CI_GATEWAY`
(`https://cloudinfra-gw.portal.checkpoint.com` for `eu`,
`https://cloudinfra-gw-us.portal.checkpoint.com` for `us`) in the shell your
agent/editor runs in, then restart it so it picks up the new MCP server -
`.mcp.json` only references `${CP_CI_CLIENT_ID}` etc., it never contains
literal credentials.

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

Recommendations for operating and extending this baseline safely:

- **Roll out gradually with `ask` before `prevent`.** Start new restrictions
  (a new tool, a new DLP data type) in `ask` mode, review the logs for a
  while, then tighten to `block`/`prevent` once you're confident about false
  positives - the same approach already used for `ask_other_genai`.
- **Respect first-match ordering.** This provider evaluates rules by
  ascending `order`, first match wins. Always put the most specific rules
  (approved tools, destructive-operation blocks) before generic catch-alls,
  and re-verify the effective order in the Infinity portal after every
  `apply` - Terraform won't catch a logical ordering mistake for you.
- **Keep `logging = "enabled"` on every rule.** Every rule in this baseline
  logs by default; don't turn it off, even for `allow` rules - logs are what
  let you validate a rollout before tightening it.
- **Never commit secrets.** `terraform.tfvars` and Terraform state can
  contain the API client ID/access key; both are already covered by
  `.gitignore` - keep it that way, and prefer environment variables
  (`TF_VAR_*`) or a secret manager over a checked-in `.tfvars` file.
- **Treat catalog/data-type IDs as tenant-specific and re-check them.**
  `claude_app_id`, `gemini_app_id`, and every custom DLP data type ID are
  fetched from your tenant, not published statically - they can change if
  the catalog is reorganized. Re-verify them after any change on the
  Check Point side, not just at initial setup.
- **Apply least privilege to MCP servers.** Prefer an explicit allowlist
  (`allow_internal_mcp_only`) over broad allow rules, and keep the
  destructive/unsupervised-operation blocks (`DELETE`, `UPDATE`) evaluated
  *before* the allowlist so they also cover internal, trusted servers -
  defense in depth against a compromised internal server, not just external
  ones.
- **Don't blanket-exempt approved tools from file protection.** Approved
  tools (Claude, Gemini) still get `upload_file_protection` /
  `download_file_protection` set to `"enabled"`, not `"na"` - being
  organization-approved should not mean unmonitored file transfer.
- **Review disabled example/optional rules before enabling them.**
  `block_generic_paste_example`, `block_ssn_prompt`/`_upload`, and
  `block_iban_prompt`/`_upload` ship `active = false` because they are
  either aggressive (generic paste block) or need a tenant-specific data
  type ID you must supply - evaluate impact in `ask` mode or with a small
  pilot group first.
