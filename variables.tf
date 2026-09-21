variable "checkpoint_client_id" {
  description = "Client ID of the Infinity Portal API key (\"Workforce AI Security\" service)."
  type        = string
  sensitive   = true
}

variable "checkpoint_access_key" {
  description = "Access key (secret) of the Infinity Portal API key."
  type        = string
  sensitive   = true
}

variable "checkpoint_region" {
  description = "Infinity Portal API region: \"us\" or \"eu\"."
  type        = string
  default     = "eu"
}

variable "claude_app_id" {
  description = <<-EOT
    Numeric ID of the "Claude" (Anthropic) application in the tenant's Workforce
    AI catalog. Not statically published by the provider: retrieve it with a
    POST to /apps/search (Apps Catalog API) searching for "Claude". See README.md.
  EOT
  type        = number
}

variable "gemini_app_id" {
  description = <<-EOT
    Numeric ID of the "Google Gemini" application in the tenant's Workforce AI
    catalog. Retrieve it the same way as claude_app_id, searching for "Gemini".
  EOT
  type        = number
}

variable "credit_card_data_type_id" {
  description = "ID of the predefined DLP data type \"Credit Card Number\" (documented by the provider)."
  type        = string
  default     = "cf0523c1-537e-4a4b-8bb8-084b7b9e0b45"
}

variable "secrets_data_type_id" {
  description = <<-EOT
    ID of the DLP data type used to redact secrets / API keys / credentials in
    prompts. Defaults to the tenant's PRE_DEFINED "Credentials" type, since
    neither this provider nor the workforce-ai MCP server can create a CUSTOM
    data type (that requires the DLP Datatypes API / Infinity portal
    directly). Override with a CUSTOM type's UUID for broader coverage (e.g.
    raw source code) - see README.md.
  EOT
  type        = string
  default     = "e2543f91-701c-4663-9a01-a6d081c8dd31"
}

variable "internal_mcp_domain" {
  description = "Domain (or suffix) of the authorized internal company MCP servers."
  type        = string
  default     = "mcp.internal.example.com"
}

variable "ssn_data_type_id" {
  description = <<-EOT
    ID of the CUSTOM DLP data type for Social Security Numbers. This type
    does not exist by default: it must be created at the tenant level via
    the DLP Datatypes API, then its UUID goes here. See README.md. The
    associated rules ship disabled (active = false) until a real ID is set.
  EOT
  type        = string
  default     = ""
}

variable "iban_data_type_id" {
  description = <<-EOT
    ID of the CUSTOM DLP data type for IBAN/bank account numbers. This type
    does not exist by default: it must be created at the tenant level via
    the DLP Datatypes API, then its UUID goes here. See README.md. The
    associated rules ship disabled (active = false) until a real ID is set.
  EOT
  type        = string
  default     = ""
}
