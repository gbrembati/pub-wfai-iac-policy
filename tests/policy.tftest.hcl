mock_provider "cpwai" {}

variables {
  checkpoint_client_id  = "test-client"
  checkpoint_access_key = "test-key"
  claude_app_id         = 1
  gemini_app_id         = 2
}

run "agents_actions" {
  command = plan

  assert {
    condition = alltrue([
      for rule in [
        cpwai_workforce_ai_agents_rule.block_destructive_operations,
        cpwai_workforce_ai_agents_rule.ask_on_update_operations,
        cpwai_workforce_ai_agents_rule.allow_internal_mcp_only,
        cpwai_workforce_ai_agents_rule.block_unlisted_mcp_servers,
      ] : contains(["block", "allow"], jsondecode(rule.policy).action)
    ])
    error_message = "Agents/MCP rules support only block or allow, not ask."
  }

  assert {
    condition     = jsondecode(cpwai_workforce_ai_agents_rule.ask_on_update_operations.policy).action == "block"
    error_message = "UPDATE operations must remain blocked rather than silently allowed."
  }

  assert {
    condition = (
      cpwai_workforce_ai_agents_rule.block_destructive_operations.order == 0 &&
      cpwai_workforce_ai_agents_rule.ask_on_update_operations.order == 1 &&
      cpwai_workforce_ai_agents_rule.allow_internal_mcp_only.order == 2 &&
      cpwai_workforce_ai_agents_rule.block_unlisted_mcp_servers.order == 3
    )
    error_message = "DELETE/UPDATE blocks must precede the internal allowlist and catch-all."
  }
}

run "workforce_ai_service_scope" {
  command = plan

  assert {
    condition = alltrue([
      for rule in [
        cpwai_workforce_ai_access_rule.allow_claude,
        cpwai_workforce_ai_access_rule.allow_gemini,
        cpwai_workforce_ai_access_rule.ask_other_genai,
        cpwai_workforce_ai_chats_rule.block_credit_card_prompt,
        cpwai_workforce_ai_chats_rule.block_credit_card_upload,
        cpwai_workforce_ai_chats_rule.redact_secrets_prompt,
        cpwai_workforce_ai_chats_rule.block_ssn_prompt,
        cpwai_workforce_ai_chats_rule.block_ssn_upload,
        cpwai_workforce_ai_chats_rule.block_iban_prompt,
        cpwai_workforce_ai_chats_rule.block_iban_upload,
        cpwai_workforce_ai_chats_rule.block_generic_paste_example,
      ] : jsondecode(rule.policy).services_and_application.mode == "selected"
    ])
    error_message = "Workforce AI rules reject services_and_application.mode = all."
  }

  assert {
    condition     = jsondecode(cpwai_workforce_ai_access_rule.ask_other_genai.policy).action == "ask"
    error_message = "The access catch-all must retain its supported ask action."
  }
}