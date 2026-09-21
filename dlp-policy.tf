# --- Baseline DLP Policy: Workforce AI Chats ---
# Dangerous scenarios mitigated: financial/PII data leakage and company IP
# leakage (secrets, API keys, source code) via prompt, paste, or upload to
# any AI tool, including approved ones (defense in depth).

resource "cpwai_workforce_ai_chats_rule" "block_credit_card_prompt" {
  name        = "Block credit card numbers in prompts"
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
      mode = "all"
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
  name        = "Block credit card numbers in file uploads"
  description = "Same scenario as the prompt case, but for attached files (e.g. a CSV export of transactions)."
  order       = 1
  active      = true

  policy = jsonencode({
    event_type = "file_upload"
    action     = "prevent"
    logging    = "enabled"
    services_and_application = {
      mode = "all"
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
  name        = "Redact secrets/API keys/source code in prompts"
  description = <<-EOT
    Dangerous scenario: a developer pastes source code containing a hardcoded
    API key or credential into a prompt while asking for debugging help,
    exposing company IP and live credentials to a third-party service.

    Requires a CUSTOM data type (var.secrets_data_type_id) created at the
    tenant level via the DLP Datatypes API: see README.md.
  EOT
  order       = 2
  active      = true

  policy = jsonencode({
    event_type = "prompt"
    action     = "redact"
    logging    = "enabled"
    services_and_application = {
      mode = "all"
    }
    data_types = [
      {
        id   = var.secrets_data_type_id
        name = "Secrets / API Keys / Source Code"
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

# OPTIONAL example (disabled by default, active = false): blocks any generic
# text "paste" to tools in the Generative AI category, even without a specific
# data type. Covers the scenario of a user pasting an entire confidential
# document (contract, financial plan) that doesn't match a recognized DLP
# pattern. This is aggressive: "any-text" rules only allow block/allow, so it
# would block EVERY paste to ANY AI tool, including Claude and Gemini.
# Evaluate the impact (false positives) before enabling it.
resource "cpwai_workforce_ai_chats_rule" "block_generic_paste_example" {
  name        = "[Example, disabled] Block generic paste to any GenAI tool"
  description = "Example of an aggressive guardrail against exfiltrating unclassified documents via copy/paste."
  order       = 3
  active      = false

  policy = jsonencode({
    event_type = "paste"
    action     = "block"
    logging    = "enabled"
    services_and_application = {
      mode = "all"
    }
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}
