# --- Baseline DLP Policy: Workforce AI Chats ---
# Dangerous scenarios mitigated: financial/PII data leakage and company IP
# leakage (secrets, API keys, source code) via prompt, paste, or upload to
# any AI tool, including approved ones (defense in depth).

resource "cpwai_workforce_ai_chats_rule" "block_credit_card_prompt" {
  name        = "[Terraform] Block credit card numbers in prompts"
  description = <<-EOT
    Dangerous scenario: an employee pastes a customer's payment data (e.g. a
    credit card number) into a prompt to get a support response generated,
    exposing PCI data to a third-party service.
  EOT
  order       = 0
  active      = true

  policy = jsonencode({
    event_type = "prompt"
    action     = "prevent"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    data_types = [
      {
        id   = var.credit_card_data_type_id
        name = "Credit Card Number"
        type = "PRE_DEFINED"
      }
    ]
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_chats_rule" "block_credit_card_upload" {
  name        = "[Terraform] Block credit card numbers in file uploads"
  description = "Same scenario as the prompt case, but for attached files (e.g. a CSV export of transactions)."
  order       = 1
  active      = true

  policy = jsonencode({
    event_type = "file_upload"
    action     = "prevent"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    data_types = [
      {
        id   = var.credit_card_data_type_id
        name = "Credit Card Number"
        type = "PRE_DEFINED"
      }
    ]
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_chats_rule" "redact_secrets_prompt" {
  name        = "[Terraform] Redact secrets/API keys/source code in prompts"
  description = <<-EOT
    Dangerous scenario: a developer pastes source code containing a hardcoded
    API key or credential into a prompt while asking for debugging help,
    exposing company IP and live credentials to a third-party service.

    Uses the PRE_DEFINED "Credentials" data type (var.secrets_data_type_id):
    there is no way to create a CUSTOM data type via this provider or the
    workforce-ai MCP server, only via the DLP Datatypes API / Infinity portal
    directly. Switch to a CUSTOM type there if broader coverage (e.g. raw
    source code) is needed later - see README.md.
  EOT
  order       = 2
  active      = true

  policy = jsonencode({
    event_type = "prompt"
    action     = "redact"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    data_types = [
      {
        id   = var.secrets_data_type_id
        name = "Credentials"
        type = "PRE_DEFINED"
      }
    ]
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

# OPTIONAL example (disabled by default, active = false): blocks any generic
# text "paste" to tools in the Generative AI category, even without a specific
# data type. Covers the scenario of a user pasting an entire confidential
# document (contract, financial plan) that doesn't match a recognized DLP
# pattern. This is aggressive: "any-text" rules only allow block/allow, so it
# would block EVERY paste to ANY AI tool, including Claude and Gemini.
# Evaluate the impact (false positives) before enabling it.
resource "cpwai_workforce_ai_chats_rule" "block_ssn_prompt" {
  name        = "[Terraform] Block Social Security Numbers in prompts"
  description = <<-EOT
    Dangerous scenario: an employee pastes a customer's or another employee's
    Social Security Number into a prompt, exposing PII to a third-party
    service.

    Disabled by default: requires a CUSTOM data type (var.ssn_data_type_id)
    created at the tenant level via the DLP Datatypes API. See README.md.
  EOT
  order       = 3
  active      = var.ssn_data_type_id != ""

  policy = jsonencode({
    event_type = "prompt"
    action     = "prevent"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    data_types = [
      {
        id   = var.ssn_data_type_id
        name = "Social Security Number"
        type = "CUSTOM"
      }
    ]
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_chats_rule" "block_ssn_upload" {
  name        = "[Terraform] Block Social Security Numbers in file uploads"
  description = "Same scenario as the prompt case, but for attached files."
  order       = 4
  active      = var.ssn_data_type_id != ""

  policy = jsonencode({
    event_type = "file_upload"
    action     = "prevent"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    data_types = [
      {
        id   = var.ssn_data_type_id
        name = "Social Security Number"
        type = "CUSTOM"
      }
    ]
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_chats_rule" "block_iban_prompt" {
  name        = "[Terraform] Block IBAN/bank account numbers in prompts"
  description = <<-EOT
    Dangerous scenario: an employee pastes a customer's or the company's IBAN
    or bank account number into a prompt, exposing financial data to a
    third-party service.

    Disabled by default: requires a CUSTOM data type (var.iban_data_type_id)
    created at the tenant level via the DLP Datatypes API. See README.md.
  EOT
  order       = 5
  active      = var.iban_data_type_id != ""

  policy = jsonencode({
    event_type = "prompt"
    action     = "prevent"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    data_types = [
      {
        id   = var.iban_data_type_id
        name = "IBAN"
        type = "CUSTOM"
      }
    ]
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_chats_rule" "block_iban_upload" {
  name        = "[Terraform] Block IBAN/bank account numbers in file uploads"
  description = "Same scenario as the prompt case, but for attached files."
  order       = 6
  active      = var.iban_data_type_id != ""

  policy = jsonencode({
    event_type = "file_upload"
    action     = "prevent"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    data_types = [
      {
        id   = var.iban_data_type_id
        name = "IBAN"
        type = "CUSTOM"
      }
    ]
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_chats_rule" "block_generic_paste_example" {
  name        = "[Terraform] [Example, disabled] Block generic paste to any GenAI tool"
  description = "Example of an aggressive guardrail against exfiltrating unclassified documents via copy/paste."
  order       = 7
  active      = false

  policy = jsonencode({
    event_type = "paste"
    action     = "block"
    logging    = "enabled"
    services_and_application = {
      mode     = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}
